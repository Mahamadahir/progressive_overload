const assert = require('node:assert/strict');
const test = require('node:test');

const { _test } = require('../index');


test('unauthenticated callable request is rejected', async () => {
  await assert.rejects(
    () => _test.parseFoodLogHandler({ auth: null, data: { mode: 'meal_text', text: 'rice' } }, {
      apiKey: 'key',
      fetchImpl: async () => ({ ok: true, json: async () => ({ output_text: '{}' }) }),
    }),
    /Sign in before using AI food logging/,
  );
});

test('rejects malformed client requests', () => {
  assert.throws(() => _test.validateClientRequest({ mode: 'meal_text', text: ' ' }), /Meal text is required/);
  assert.throws(
    () => _test.validateClientRequest({
      mode: 'label_photo',
      image: { base64: 'abcd', mimeType: 'image/gif' },
    }),
    /Only JPEG and PNG/,
  );
});

test('meal_text request builds structured Gemini schema input', () => {
  const request = _test.validateClientRequest({ mode: 'meal_text', text: 'rice and chicken' });
  const input = _test.buildGeminiInput(request);

  assert.equal(input[0].type, 'text');
  assert.match(input[0].text, /rice and chicken/);
  assert.equal(_test.schemas.mealSchema.required.includes('lines'), true);
});

test('label_photo request sends inline image input', () => {
  const request = _test.validateClientRequest({
    mode: 'label_photo',
    image: { base64: 'YWJjZA==', mimeType: 'image/png' },
  });
  const input = _test.buildGeminiInput(request);

  assert.equal(input[1].type, 'image');
  assert.equal(input[1].data, 'YWJjZA==');
  assert.equal(input[1].mime_type, 'image/png');
});

test('validates meal rows and clamps confidence', () => {
  const response = _test.validateGeminiResponse('meal_text', {
    kind: 'meal',
    mealName: 'Lunch',
    lines: [{ name: 'Rice', grams: 120, kcalPer100g: 130, confidence: 2 }],
    warnings: ['estimated'],
  });

  assert.equal(response.lines[0].confidence, 1);
  assert.equal(response.lines[0].grams, 120);
});

test('rejects invalid Gemini numbers', () => {
  assert.throws(
    () => _test.validateGeminiResponse('meal_text', {
      kind: 'meal',
      mealName: 'Lunch',
      lines: [{ name: 'Rice', grams: Number.NaN, kcalPer100g: 130, confidence: 0.8 }],
      warnings: [],
    }),
    /invalid grams/,
  );
});

test('malformed Gemini JSON returns a controlled error', async () => {
  await assert.rejects(
    () => _test.callGemini({
      apiKey: 'key',
      model: 'gemini-3.5-flash',
      input: [],
      schema: {},
      fetchImpl: async () => ({
        ok: true,
        json: async () => ({ output_text: '{' }),
      }),
    }),
    /malformed JSON/,
  );
});
