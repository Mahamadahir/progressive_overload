import 'package:flutter/material.dart';
import '../services/meal_service.dart';
import '../models/meal_template.dart';
import '../models/food_component.dart';
import '../models/meal_component_line.dart';
import '../models/meal_log.dart';

class LogCaloriesPage extends StatefulWidget {
  const LogCaloriesPage({super.key});

  @override
  State<LogCaloriesPage> createState() => _LogCaloriesPageState();
}

enum LogMode { newMeal, savedMeal }

class _LogCaloriesPageState extends State<LogCaloriesPage> {
  final _svc = MealService();

  LogMode _mode = LogMode.newMeal;

  // Build-by-components state
  final _mealNameCtrl = TextEditingController();
  final List<_LineEditor> _lines = [];

  // Saved meal state
  MealTemplate? _selectedTemplate;
  final _searchTemplateCtrl = TextEditingController();
  List<MealTemplate> _templates = [];
  List<MealTemplate> _recentTemplates = [];

  // Components search/create
  final _searchComponentCtrl = TextEditingController();
  List<FoodComponent> _components = [];

  // Today logs
  List<MealLog> _todayLogs = [];

  String? _msg;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _refreshAll();
    _searchTemplateCtrl.addListener(
      () => setState(() {
        _updateTemplateList(_svc.searchTemplates(_searchTemplateCtrl.text));
      }),
    );
    _searchComponentCtrl.addListener(
      () => setState(() {
        _updateComponentList(_svc.searchComponents(_searchComponentCtrl.text));
      }),
    );
    if (_lines.isEmpty) _lines.add(_LineEditor());
  }

  Future<void> _refreshAll() async {
    setState(() {
      final search = _searchTemplateCtrl.text;
      final templates = search.isEmpty
          ? _svc.getAllTemplates()
          : _svc.searchTemplates(search);
      _updateTemplateList(templates);
      _recentTemplates = _svc.recentTemplates();
      _updateComponentList(_svc.getAllComponents());
      _todayLogs = _svc.todayLogs();
    });
  }

  double _totalKcal() {
    double sum = 0;
    for (final le in _lines) {
      final c = le.component;
      final g = double.tryParse(le.gramsCtrl.text) ?? 0;
      if (c != null && g > 0) {
        sum += c.kcalPer100g * g / 100.0;
      }
    }
    return sum;
  }

  double _totalMass() {
    double sum = 0;
    for (final le in _lines) {
      final g = double.tryParse(le.gramsCtrl.text) ?? 0;
      sum += g;
    }
    return sum;
  }

  List<MealComponentLine> _collectLines() {
    final out = <MealComponentLine>[];
    for (final le in _lines) {
      final c = le.component;
      final g = double.tryParse(le.gramsCtrl.text) ?? 0;
      if (c != null && g > 0) {
        out.add(MealComponentLine(componentId: c.id, grams: g));
      }
    }
    return out;
  }

  MealTemplate? _findTemplateById(String id, Iterable<MealTemplate> source) {
    for (final template in source) {
      if (template.id == id) {
        return template;
      }
    }
    return null;
  }

  FoodComponent? _findComponentById(String id, Iterable<FoodComponent> source) {
    for (final component in source) {
      if (component.id == id) {
        return component;
      }
    }
    return null;
  }

  void _syncLineEditorsWithComponents() {
    final byId = {for (final component in _components) component.id: component};
    for (final editor in _lines) {
      final id = editor.component?.id;
      if (id == null) continue;
      editor.component = byId[id];
    }
  }

  void _updateTemplateList(List<MealTemplate> templates) {
    final selectedId = _selectedTemplate?.id;
    _templates = templates;
    if (selectedId != null) {
      _selectedTemplate = _findTemplateById(selectedId, templates);
    }
  }

  void _updateComponentList(List<FoodComponent> components) {
    final merged = <FoodComponent>[];
    final seen = <String>{};

    void addComponent(FoodComponent component) {
      if (seen.add(component.id)) {
        merged.add(component);
      }
    }

    for (final component in components) {
      addComponent(component);
    }
    for (final editor in _lines) {
      final comp = editor.component;
      if (comp != null) {
        addComponent(comp);
      }
    }

    _components = merged;
    _syncLineEditorsWithComponents();
  }

  void _selectTemplate(MealTemplate? template) {
    if (template != null) {
      final resolved = _findTemplateById(template.id, _templates) ?? template;
      _selectedTemplate = resolved;
      _lines
        ..clear()
        ..addAll(
          resolved.lines.map((line) {
            final comp =
                _findComponentById(line.componentId, _components) ??
                _svc.getComponent(line.componentId);
            return _LineEditor(component: comp, grams: line.grams);
          }),
        );
      if (_lines.isEmpty) {
        _lines.add(_LineEditor());
      }
      _mealNameCtrl.text = resolved.name;
      _updateComponentList(_components);
    } else {
      _selectedTemplate = null;
      if (_lines.isEmpty) {
        _lines.add(_LineEditor());
      }
    }
  }

  Future<void> _logCurrentMeal({
    String? templateId,
    required String name,
  }) async {
    final lines = _collectLines();
    if (name.trim().isEmpty) throw 'Enter a meal name';
    if (lines.isEmpty) throw 'Add at least one component with grams > 0';

    // AUTOSAVE: update or create template to match current composition
    final t = await _svc.createOrUpdateTemplateFromLines(
      id: templateId,
      name: name,
      lines: lines,
    );

    await _svc.logMealFromLines(templateId: t.id, name: t.name, lines: lines);

    setState(
      () => _msg =
          'Logged ${t.name} • ${_totalMass().toStringAsFixed(0)} g • ${_totalKcal().toStringAsFixed(0)} kcal',
    );
    await _refreshAll();
  }

  Future<void> _newComponentDialog() async {
    final nameCtrl = TextEditingController();
    final kcalCtrl = TextEditingController(text: '100');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New component'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: kcalCtrl,
              decoration: const InputDecoration(labelText: 'kcal per 100g'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final name = nameCtrl.text.trim();
      final kcal = double.tryParse(kcalCtrl.text) ?? 0;
      if (name.isEmpty || kcal <= 0) {
        setState(() => _msg = 'Enter valid name and kcal/100g > 0');
        return;
      }
      await _svc.createOrUpdateComponent(name: name, kcalPer100g: kcal);
      setState(() {
        _updateComponentList(_svc.getAllComponents());
        _msg = 'Added component "$name"';
      });
    }
  }

  // Template edit/delete
  Future<void> _editTemplate(MealTemplate t) async {
    // Load lines into editor
    _mode = LogMode.savedMeal;
    _selectTemplate(t);
    setState(() {});
  }

  Future<void> _deleteTemplate(MealTemplate t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete saved meal?'),
        content: Text('Remove "${t.name}" from saved meals? Logs remain.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _svc.deleteTemplate(t.id);
      _selectTemplate(null);
      await _refreshAll();
      setState(() => _msg = 'Deleted "${t.name}"');
    }
  }

  // Log edit/delete
  Future<void> _editLog(MealLog log) async {
    // Build editors from snapshot
    final editors = <_LineEditor>[];
    final snapshot = log.snapshot ?? [];
    for (final s in snapshot) {
      // Try map snapshot name to an existing component; fallback to ad-hoc by name
      final comp = _svc.getAllComponents().firstWhere(
        (c) => c.name.toLowerCase() == s.name.toLowerCase(),
        orElse: () => FoodComponent(
          id: 'adhoc:${s.name}',
          name: s.name,
          kcalPer100g: s.kcalPer100g,
        ),
      );
      editors.add(_LineEditor(component: comp, grams: s.grams));
    }

    final nameCtrl = TextEditingController(text: log.name);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) {
          double dialogKcal() {
            double k = 0;
            for (final e in editors) {
              final g = double.tryParse(e.gramsCtrl.text) ?? 0;
              final c = e.component;
              if (c != null && g > 0) k += c.kcalPer100g * g / 100;
            }
            return k;
          }

          return AlertDialog(
            title: const Text('Edit logged meal'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Meal name'),
                    ),
                    const SizedBox(height: 8),
                    ...editors.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final le = entry.value;
                      return Row(
                        children: [
                          Expanded(
                            child: DropdownButton<FoodComponent>(
                              value:
                                  le.component is FoodComponent &&
                                      !(le.component!.id.startsWith('adhoc:'))
                                  ? le.component
                                  : null,
                              hint: Text(le.component?.name ?? 'Component'),
                              items: _svc
                                  .getAllComponents()
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (c) => setStateDialog(() {
                                le.component = c;
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 90,
                            child: TextField(
                              controller: le.gramsCtrl,
                              decoration: const InputDecoration(labelText: 'g'),
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setStateDialog(() {}),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                setStateDialog(() => editors.removeAt(idx)),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Total: ${dialogKcal().toStringAsFixed(0)} kcal',
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add component'),
                      onPressed: () =>
                          setStateDialog(() => editors.add(_LineEditor())),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true) {
      final newLines = <MealComponentLine>[];
      for (final e in editors) {
        final c = e.component;
        final g = double.tryParse(e.gramsCtrl.text) ?? 0;
        if (c != null && !c.id.startsWith('adhoc:') && g > 0) {
          newLines.add(MealComponentLine(componentId: c.id, grams: g));
        }
      }
      // Update log composition (doesn't touch template)
      await _svc.updateLogFromNewLines(log.id, newLines);
      await _refreshAll();
      setState(() => _msg = 'Updated "${log.name}"');
    }
  }

  Future<void> _deleteLog(MealLog log) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete log?'),
        content: Text('Remove "${log.name}" from today?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _svc.deleteLog(log.id);
      await _refreshAll();
      setState(() => _msg = 'Deleted "${log.name}"');
    }
  }

  @override
  void dispose() {
    _mealNameCtrl.dispose();
    _searchTemplateCtrl.dispose();
    _searchComponentCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalKcal = _totalKcal();
    final totalMass = _totalMass();

    return Scaffold(
      appBar: AppBar(title: const Text('Log Calories')),
      body: _saving
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  SegmentedButton<LogMode>(
                    segments: const [
                      ButtonSegment(
                        value: LogMode.newMeal,
                        label: Text('Build meal'),
                      ),
                      ButtonSegment(
                        value: LogMode.savedMeal,
                        label: Text('Saved meals'),
                      ),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() {
                      _mode = s.first;
                      _msg = null;
                    }),
                  ),
                  const SizedBox(height: 16),

                  if (_mode == LogMode.newMeal) ...[
                    TextField(
                      controller: _mealNameCtrl,
                      decoration: const InputDecoration(labelText: 'Meal name'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _searchComponentCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Search components',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _components
                          .take(8)
                          .map(
                            (c) => ChoiceChip(
                              label: Text(c.name),
                              selected: false,
                              onSelected: (_) => setState(() {
                                _lines.add(_LineEditor(component: c));
                                _updateComponentList(_components);
                              }),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('New component'),
                      onPressed: _newComponentDialog,
                    ),
                    const SizedBox(height: 12),
                    ..._lines.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final le = entry.value;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<FoodComponent>(
                                  initialValue: le.component,
                                  items: _components
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(c.name),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (c) => setState(() {
                                    le.component = c;
                                    _updateComponentList(_components);
                                  }),
                                  decoration: const InputDecoration(
                                    labelText: 'Component',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 100,
                                child: TextField(
                                  controller: le.gramsCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'g',
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () =>
                                    setState(() => _lines.removeAt(idx)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add component row'),
                      onPressed: () =>
                          setState(() => _lines.add(_LineEditor())),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Total: ${totalMass.toStringAsFixed(0)} g • ${totalKcal.toStringAsFixed(0)} kcal',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        setState(() => _saving = true);
                        try {
                          await _logCurrentMeal(name: _mealNameCtrl.text);
                        } catch (e) {
                          setState(() => _msg = 'Error: $e');
                        } finally {
                          setState(() => _saving = false);
                        }
                      },
                      child: const Text('Log meal'),
                    ),
                  ],

                  if (_mode == LogMode.savedMeal) ...[
                    TextField(
                      controller: _searchTemplateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Search saved meals',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_recentTemplates.isNotEmpty) ...[
                      Text(
                        'Recent',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _recentTemplates
                            .map(
                              (t) => Tooltip(
                                message: 'Tap to load or delete',
                                waitDuration: const Duration(milliseconds: 400),
                                child: InputChip(
                                  label: Text(t.name),
                                  selected: _selectedTemplate?.id == t.id,
                                  onPressed: () => setState(() {
                                    if (_findTemplateById(t.id, _templates) ==
                                        null) {
                                      _updateTemplateList(
                                        _svc.getAllTemplates(),
                                      );
                                      if (_searchTemplateCtrl.text.isNotEmpty) {
                                        _searchTemplateCtrl.text = '';
                                      }
                                    }
                                    _selectTemplate(t);
                                  }),
                                  onDeleted: () => _deleteTemplate(t),
                                  deleteIcon: const Icon(Icons.delete_outline),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<MealTemplate>(
                            initialValue: _selectedTemplate,
                            items: _templates
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (t) => setState(() {
                              _selectTemplate(t);
                            }),
                            decoration: const InputDecoration(
                              labelText: 'Select saved meal',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Edit saved meal (load & modify)',
                          icon: const Icon(Icons.edit),
                          onPressed: _selectedTemplate == null
                              ? null
                              : () => _editTemplate(_selectedTemplate!),
                        ),
                        IconButton(
                          tooltip: 'Delete saved meal',
                          icon: const Icon(Icons.delete_forever),
                          onPressed: _selectedTemplate == null
                              ? null
                              : () => _deleteTemplate(_selectedTemplate!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // show editable lines for selected template
                    if (_selectedTemplate != null) ...[
                      ..._lines.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final le = entry.value;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<FoodComponent>(
                                    initialValue: le.component,
                                    items: _components
                                        .map(
                                          (c) => DropdownMenuItem(
                                            value: c,
                                            child: Text(c.name),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (c) => setState(() {
                                      le.component = c;
                                    }),
                                    decoration: const InputDecoration(
                                      labelText: 'Component',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 100,
                                  child: TextField(
                                    controller: le.gramsCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'g',
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () =>
                                      setState(() => _lines.removeAt(idx)),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add component row'),
                        onPressed: () =>
                            setState(() => _lines.add(_LineEditor())),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total: ${totalMass.toStringAsFixed(0)} g • ${totalKcal.toStringAsFixed(0)} kcal',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () async {
                          setState(() => _saving = true);
                          try {
                            await _logCurrentMeal(
                              templateId: _selectedTemplate!.id,
                              name: _mealNameCtrl.text,
                            );
                          } catch (e) {
                            setState(() => _msg = 'Error: $e');
                          } finally {
                            setState(() => _saving = false);
                          }
                        },
                        child: const Text('Log meal'),
                      ),
                    ],
                  ],

                  if (_msg != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _msg!,
                      style: TextStyle(
                        color: _msg!.startsWith('Error')
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                  ],

                  const Divider(height: 32),

                  Text(
                    'Today\'s logged meals',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ..._todayLogs.map((log) {
                    final breakdown = (log.snapshot ?? [])
                        .map(
                          (s) =>
                              '${s.name}: ${s.grams.toStringAsFixed(0)}g • ${s.kcal.toStringAsFixed(0)} kcal',
                        )
                        .join('  •  ');
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.restaurant_menu),
                        title: Text(log.name),
                        subtitle: Text(
                          '${log.totalMassGrams?.toStringAsFixed(0) ?? log.massGrams.toStringAsFixed(0)} g • ${log.kcal.toStringAsFixed(0)} kcal\n$breakdown',
                        ),
                        isThreeLine: true,
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: 'Edit logged meal',
                              onPressed: () => _editLog(log),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              tooltip: 'Delete',
                              onPressed: () => _deleteLog(log),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

class _LineEditor {
  FoodComponent? component;
  final TextEditingController gramsCtrl;

  _LineEditor({this.component, double? grams})
    : gramsCtrl = TextEditingController(text: (grams ?? 0).toStringAsFixed(0));

  void dispose() => gramsCtrl.dispose();
}
