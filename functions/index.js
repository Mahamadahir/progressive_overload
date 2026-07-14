const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');

const geminiApiKey = defineSecret('GEMINI_API_KEY');

const maxTextLength = 2000;
const maxImageBase64Length = 6 * 1024 * 1024;
const allowedImageMimeTypes = new Set(['image/jpeg', 'image/png']);
const interactionsEndpoint = 'https://generativelanguage.googleapis.com/v1beta/interactions';

const mealSchema = {
  type: 'object',
  properties: {
    kind: { type: 'string', enum: ['meal'] },
    mealName: { type: 'string' },
    lines: {
      type: 'array',
      minItems: 1,
      items: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          grams: { type: 'number' },
          kcalPer100g: { type: 'number' },
          confidence: { type: 'number' },
        },
        required: ['name', 'grams', 'kcalPer100g', 'confidence'],
      },
    },
    warnings: { type: 'array', items: { type: 'string' } },
  },
  required: ['kind', 'mealName', 'lines', 'warnings'],
};

const componentSchema = {
  type: 'object',
  properties: {
    kind: { type: 'string', enum: ['component'] },
    name: { type: 'string' },
    kcalPer100g: { type: 'number' },
    servingSizeGrams: { type: 'number' },
    kcalPerServing: { type: 'number' },
    confidence: { type: 'number' },
    warnings: { type: 'array', items: { type: 'string' } },
  },
  required: [
    'kind',
    'name',
    'kcalPer100g',
    'servingSizeGrams',
    'kcalPerServing',
    'confidence',
    'warnings',
  ],
};

exports.parseFoodLog = onCall(
  { secrets: [geminiApiKey], timeoutSeconds: 60, memory: '256MiB' },
  (request) => parseFoodLogHandler(request),
);

async function parseFoodLogHandler(request, options = {}) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in before using AI food logging.');
  }

  const parsedRequest = validateClientRequest(request.data);
  const schema = parsedRequest.mode === 'meal_text' ? mealSchema : componentSchema;
  const input = buildGeminiInput(parsedRequest);

  try {
    const geminiJson = await callGemini({
      apiKey: options.apiKey ?? geminiApiKey.value(),
      model: options.model ?? process.env.GEMINI_MODEL ?? 'gemini-3.5-flash',
      input,
      schema,
      fetchImpl: options.fetchImpl ?? fetch,
    });
    return validateGeminiResponse(parsedRequest.mode, geminiJson);
  } catch (error) {
    if (error instanceof HttpsError) {
      throw error;
    }
    logger.error('Gemini food parse failed', {
      mode: parsedRequest.mode,
      message: error.message,
    });
    throw new HttpsError('internal', 'AI parsing failed. Try again.');
  }
}

function validateClientRequest(data) {
  if (!data || typeof data !== 'object') {
    throw new HttpsError('invalid-argument', 'Request body is required.');
  }

  if (data.mode === 'meal_text') {
    const text = typeof data.text === 'string' ? data.text.trim() : '';
    if (!text) {
      throw new HttpsError('invalid-argument', 'Meal text is required.');
    }
    if (text.length > maxTextLength) {
      throw new HttpsError('invalid-argument', 'Meal text is too long.');
    }
    return { mode: data.mode, text };
  }

  if (data.mode === 'label_photo') {
    const image = data.image;
    if (!image || typeof image !== 'object') {
      throw new HttpsError('invalid-argument', 'Image payload is required.');
    }
    const base64 = typeof image.base64 === 'string' ? image.base64 : '';
    const mimeType = typeof image.mimeType === 'string' ? image.mimeType : '';
    if (!base64) {
      throw new HttpsError('invalid-argument', 'Image data is required.');
    }
    if (!allowedImageMimeTypes.has(mimeType)) {
      throw new HttpsError('invalid-argument', 'Only JPEG and PNG label photos are supported.');
    }
    if (base64.length > maxImageBase64Length || !isBase64(base64)) {
      throw new HttpsError('invalid-argument', 'Image payload is too large or invalid.');
    }
    return { mode: data.mode, image: { base64, mimeType } };
  }

  throw new HttpsError('invalid-argument', 'Unsupported AI food log mode.');
}

function buildGeminiInput(request) {
  if (request.mode === 'meal_text') {
    return [
      {
        type: 'text',
        text: [
          'Extract a meal draft for a calorie logging app.',
          'Return grams and kcal per 100g for each distinct food line.',
          'Use warnings for missing quantities, uncertainty, or assumptions.',
          `Meal description: ${request.text}`,
        ].join('\n'),
      },
    ];
  }

  return [
    {
      type: 'text',
      text: [
        'Extract packaged-food nutrition facts from this label photo.',
        'Return one component with kcal per 100g, serving size grams, and kcal per serving.',
        'Use warnings for unreadable or inferred values.',
      ].join('\n'),
    },
    {
      type: 'image',
      data: request.image.base64,
      mime_type: request.image.mimeType,
    },
  ];
}

async function callGemini({ apiKey, model, input, schema, fetchImpl }) {
  if (!apiKey) {
    throw new HttpsError('failed-precondition', 'Gemini API key is not configured.');
  }

  const response = await fetchImpl(interactionsEndpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    },
    body: JSON.stringify({
      model,
      input,
      response_format: {
        type: 'text',
        mime_type: 'application/json',
        schema,
      },
    }),
  });

  if (!response.ok) {
    throw new HttpsError('unavailable', 'Gemini request failed.');
  }

  const payload = await response.json();
  const outputText = payload.output_text;
  if (typeof outputText !== 'string' || !outputText.trim()) {
    throw new HttpsError('internal', 'Gemini returned an empty response.');
  }

  try {
    return JSON.parse(outputText);
  } catch (error) {
    throw new HttpsError('internal', 'Gemini returned malformed JSON.');
  }
}

function validateGeminiResponse(mode, json) {
  if (!json || typeof json !== 'object' || Array.isArray(json)) {
    throw new HttpsError('internal', 'Gemini returned malformed JSON.');
  }

  if (mode === 'meal_text') {
    if (json.kind !== 'meal' || typeof json.mealName !== 'string' || !json.mealName.trim()) {
      throw new HttpsError('internal', 'Gemini returned an invalid meal.');
    }
    if (!Array.isArray(json.lines) || json.lines.length === 0) {
      throw new HttpsError('internal', 'Gemini returned no meal rows.');
    }
    return {
      kind: 'meal',
      mealName: json.mealName.trim(),
      lines: json.lines.map(validateMealLine),
      warnings: validateWarnings(json.warnings),
    };
  }

  if (json.kind !== 'component' || typeof json.name !== 'string' || !json.name.trim()) {
    throw new HttpsError('internal', 'Gemini returned an invalid component.');
  }
  return {
    kind: 'component',
    name: json.name.trim(),
    kcalPer100g: readPositiveNumber(json.kcalPer100g, 'kcalPer100g'),
    servingSizeGrams: readPositiveNumber(json.servingSizeGrams, 'servingSizeGrams'),
    kcalPerServing: readPositiveNumber(json.kcalPerServing, 'kcalPerServing'),
    confidence: readConfidence(json.confidence),
    warnings: validateWarnings(json.warnings),
  };
}

function validateMealLine(line) {
  if (!line || typeof line !== 'object' || typeof line.name !== 'string' || !line.name.trim()) {
    throw new HttpsError('internal', 'Gemini returned an invalid meal row.');
  }
  return {
    name: line.name.trim(),
    grams: readPositiveNumber(line.grams, 'grams'),
    kcalPer100g: readPositiveNumber(line.kcalPer100g, 'kcalPer100g'),
    confidence: readConfidence(line.confidence),
  };
}

function readPositiveNumber(value, fieldName) {
  const number = Number(value);
  if (!Number.isFinite(number) || number <= 0) {
    throw new HttpsError('internal', `Gemini returned invalid ${fieldName}.`);
  }
  return number;
}

function readConfidence(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) {
    throw new HttpsError('internal', 'Gemini returned invalid confidence.');
  }
  return Math.min(1, Math.max(0, number));
}

function validateWarnings(value) {
  if (value == null) return [];
  if (!Array.isArray(value)) {
    throw new HttpsError('internal', 'Gemini returned invalid warnings.');
  }
  return value.filter((item) => typeof item === 'string').map((item) => item.trim()).filter(Boolean);
}

function isBase64(value) {
  if (!/^[A-Za-z0-9+/]+={0,2}$/.test(value)) return false;
  return value.length % 4 === 0;
}

exports._test = {
  parseFoodLogHandler,
  buildGeminiInput,
  callGemini,
  validateClientRequest,
  validateGeminiResponse,
  schemas: { mealSchema, componentSchema },
};
