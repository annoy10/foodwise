
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/api.dart';
import 'advanced_screen.dart';
import 'rag_chat_screen.dart';

const green = Color(0xFF278B4D);
const ink = Color(0xFF19322A);
const muted = Color(0xFF728378);

double number(dynamic v) => double.tryParse('$v') ?? 0;

String fmt(dynamic v, [int decimals = 1]) =>
    number(v).toStringAsFixed(decimals);

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.api,
    required this.onLogout,
  });

  final Api api;
  final VoidCallback onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int page = 0;
  bool loading = true;
  bool busy = false;
  String? error;

  List<dynamic> foods = [];
  List<dynamic> meals = [];
  Map<String, dynamic> summary = {};

  int? foodId;
  String mealType = 'breakfast';

  final grams = TextEditingController(text: '100');
  final foodName = TextEditingController();
  final calories = TextEditingController();
  final protein = TextEditingController();
  final carbs = TextEditingController();
  final fat = TextEditingController();
  final search = TextEditingController();

  DateTime selectedDate = DateTime.now();

  String get today =>
      '${selectedDate.year}-'
          '${selectedDate.month.toString().padLeft(2, '0')}-'
          '${selectedDate.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void dispose() {
    for (final controller in [
      grams,
      foodName,
      calories,
      protein,
      carbs,
      fat,
      search,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> pickDate() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (chosen != null && mounted) {
      setState(() => selectedDate = chosen);
      await refresh();
    }
  }

  Future<void> moveDay(int days) async {
    final d = selectedDate.add(Duration(days: days));

    if (d.isAfter(DateUtils.dateOnly(DateTime.now()))) {
      return;
    }

    setState(() => selectedDate = d);
    await refresh();
  }

  Future<void> refresh() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final result = await Future.wait<dynamic>([
        widget.api.foods(),
        widget.api.meals(today),
        widget.api.summary(today),
      ]);

      if (!mounted) return;

      setState(() {
        foods = result[0] as List<dynamic>;
        meals = result[1] as List<dynamic>;
        summary = result[2] as Map<String, dynamic>;

        if (!foods.any((f) => f['id'] == foodId)) {
          foodId = null;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  void notice(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> addFood() async {
    final name = foodName.text.trim();

    final values = [
      calories,
      protein,
      carbs,
      fat,
    ].map((c) => double.tryParse(c.text.trim())).toList();

    if (name.length < 2 ||
        values.any((v) => v == null || v < 0)) {
      notice(
        'Enter a food name and non-negative nutrition values per 100g',
      );
      return;
    }

    setState(() => busy = true);

    try {
      await widget.api.addFood(
        name,
        values[0]!,
        values[1]!,
        values[2]!,
        values[3]!,
      );

      for (final c in [
        foodName,
        calories,
        protein,
        carbs,
        fat,
      ]) {
        c.clear();
      }

      await refresh();
      notice('Food added successfully');
    } catch (e) {
      notice('Could not add food: $e');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> addMeal() async {
    final qty = double.tryParse(grams.text.trim());

    if (foodId == null || qty == null || qty <= 0) {
      notice('Select a food and enter a positive quantity');
      return;
    }

    setState(() => busy = true);

    try {
      await widget.api.addMeal(
        foodId!,
        mealType,
        qty,
        today,
      );

      await refresh();
      notice('Meal saved');
    } catch (e) {
      notice('Could not save meal: $e');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> removeMeal(int id) async {
    setState(() => busy = true);

    try {
      await widget.api.deleteMeal(id);
      await refresh();
      notice('Meal removed');
    } catch (e) {
      notice('Could not remove meal: $e');
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Widget panel(
      String title,
      IconData icon,
      Widget child, {
        String? sub,
      }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: green),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: ink,
                    ),
                  ),
                ),
              ],
            ),
            if (sub != null) ...[
              const SizedBox(height: 5),
              Text(
                sub,
                style: const TextStyle(color: muted),
              ),
            ],
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }

  Widget textBox(
      String label,
      TextEditingController controller, {
        bool numeric = false,
      }) {
    return TextField(
      controller: controller,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget mealForm() {
    return panel(
      'Add a Meal',
      Icons.restaurant_menu,
      Column(
        children: [
          DropdownButtonFormField<int>(
            key: ValueKey('food-$foodId-${foods.length}'),
            initialValue: foodId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Food'),
            hint: const Text('Choose a food'),
            items: foods.map((f) {
              return DropdownMenuItem<int>(
                value: f['id'] as int,
                child: Text(
                  '${f['name']}  '
                      '(${fmt(f['calories'], 0)} kcal / 100g)',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (v) => setState(() => foodId = v),
          ),
          if (foods.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 9),
              child: Text(
                'No foods yet. Add your first food using the form on the right.',
                style: TextStyle(color: muted),
              ),
            ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: mealType,
            decoration: const InputDecoration(
              labelText: 'Meal type',
            ),
            items: const [
              'breakfast',
              'lunch',
              'dinner',
              'snack',
            ].map((m) {
              return DropdownMenuItem<String>(
                value: m,
                child: Text(
                  m[0].toUpperCase() + m.substring(1),
                ),
              );
            }).toList(),
            onChanged: (v) {
              setState(() => mealType = v ?? 'breakfast');
            },
          ),
          const SizedBox(height: 14),
          textBox(
            'Quantity (grams)',
            grams,
            numeric: true,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : addMeal,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save Meal'),
            ),
          ),
        ],
      ),
      sub: 'Log what you ate today.',
    );
  }

  Widget foodForm() {
    return panel(
      'Add a New Food',
      Icons.eco,
      Column(
        children: [
          textBox('Food name', foodName),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 360;

              Widget pair(Widget a, Widget b) {
                if (narrow) {
                  return Column(
                    children: [
                      a,
                      const SizedBox(height: 12),
                      b,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: a),
                    const SizedBox(width: 12),
                    Expanded(child: b),
                  ],
                );
              }

              return Column(
                children: [
                  pair(
                    textBox(
                      'Calories / 100g',
                      calories,
                      numeric: true,
                    ),
                    textBox(
                      'Protein (g)',
                      protein,
                      numeric: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  pair(
                    textBox(
                      'Carbs (g)',
                      carbs,
                      numeric: true,
                    ),
                    textBox(
                      'Fat (g)',
                      fat,
                      numeric: true,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : addFood,
              icon: const Icon(Icons.add),
              label: const Text('Add Food'),
            ),
          ),
        ],
      ),
      sub: 'Nutrition values are for 100 grams.',
    );
  }

  Widget metric(
      String title,
      String value,
      IconData icon,
      Color color,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withValues(alpha: .12),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 21,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget statCards(double width) {
    final items = [
      metric(
        'Total calories',
        '${fmt(summary['calories'], 0)} kcal',
        Icons.local_fire_department,
        green,
      ),
      metric(
        'Protein',
        '${fmt(summary['protein'])} g',
        Icons.fitness_center,
        Colors.redAccent,
      ),
      metric(
        'Carbs',
        '${fmt(summary['carbs'])} g',
        Icons.grain,
        Colors.orange,
      ),
      metric(
        'Fat',
        '${fmt(summary['fat'])} g',
        Icons.water_drop,
        Colors.blue,
      ),
    ];

    if (width <= 490) {
      return Column(
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              width: double.infinity,
              child: item,
            ),
          );
        }).toList(),
      );
    }

    return GridView.count(
      crossAxisCount: width > 880 ? 4 : 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      mainAxisExtent: 110,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: items,
    );
  }

  Widget mealHistory() {
    return panel(
      "Today's Meals",
      Icons.history,
      meals.isEmpty
          ? const Text(
        'No meals logged today. Add your first meal!',
        style: TextStyle(color: muted),
      )
          : Column(
        children: meals.map((m) {
          final food = foods
              .where((f) => f['id'] == m['food_id'])
              .toList();

          final f = food.isEmpty ? null : food.first;

          final cals = f == null
              ? 0.0
              : number(f['calories']) *
              number(m['quantity_grams']) /
              100;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAF7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFDEF4E4),
                  child: Icon(
                    Icons.lunch_dining,
                    color: green,
                  ),
                ),
                title: Text(
                  f?['name']?.toString() ??
                      'Food #${m['food_id']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${m['quantity_grams']} g · ${m['meal_type']}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${cals.toStringAsFixed(0)} kcal',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      onPressed: busy
                          ? null
                          : () => removeMeal(m['id'] as int),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      tooltip: 'Delete meal',
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget chart() {
    final proteinCal = number(summary['protein']) * 4;
    final carbCal = number(summary['carbs']) * 4;
    final fatCal = number(summary['fat']) * 9;

    final parts = [
      proteinCal,
      carbCal,
      fatCal,
    ];

    final total = parts.reduce((a, b) => a + b);

    final colors = [
      Colors.redAccent,
      Colors.amber,
      Colors.blueAccent,
    ];

    final titles = [
      'Protein',
      'Carbs',
      'Fat',
    ];

    return panel(
      'Nutrition Breakdown',
      Icons.donut_large,
      Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _DonutPainter(parts, colors),
              child: Center(
                child: Text(
                  '${fmt(summary['calories'], 0)}\nkcal',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              children: List.generate(3, (i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 5,
                        backgroundColor: colors[i],
                      ),
                      const SizedBox(width: 7),
                      Expanded(child: Text(titles[i])),
                      Text(
                        total == 0
                            ? '0%'
                            : '${(parts[i] / total * 100).round()}%',
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget foodCatalog() {
    final q = search.text.toLowerCase();

    final filtered = foods.where((f) {
      return f['name']
          .toString()
          .toLowerCase()
          .contains(q);
    }).toList();

    return panel(
      'Food Database',
      Icons.storage,
      Column(
        children: [
          TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search foods',
            ),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            const Text(
              'No matching foods',
              style: TextStyle(color: muted),
            ),
          ...filtered.map((f) {
            return ListTile(
              leading: const Icon(
                Icons.eco,
                color: green,
              ),
              title: Text(f['name'].toString()),
              subtitle: Text(
                'P ${fmt(f['protein'])}g · '
                    'C ${fmt(f['carbs'])}g · '
                    'F ${fmt(f['fat'])}g / 100g',
              ),
              trailing: Text(
                '${fmt(f['calories'], 0)} kcal',
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget twoColumns(
      Widget a,
      Widget b,
      double width,
      ) {
    if (width > 850) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          const SizedBox(width: 12),
          Expanded(child: b),
        ],
      );
    }

    return Column(children: [a, b]);
  }

  String labelsForPage(int index) {
    return const [
      'Dashboard',
      'Add Meal',
      'Add Food',
      'Food Database',
      'Meal History',
      'Nutrition Report',
      'Weekly / Monthly',
      'Nutrition Goals',
      'Water Tracker',
      'Profile & Settings',
      'Favorites',
      'RAG Recipe Chat',
    ][index];
  }

  // FIXED: RAG Chat now has its own bounded layout.
  Widget content(double width) {
    if (page == 11) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final availableHeight =
          (constraints.maxHeight - 32)
              .clamp(200.0, double.infinity)
              .toDouble();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 1260,
                ),
                child: SizedBox(
                  height: availableHeight,
                  child: RagChatScreen(
                    api: widget.api,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(60),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load data: $error'),
            TextButton(
              onPressed: refresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1260,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                labelsForPage(page),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: () => moveDay(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: pickDate,
                      icon: const Icon(
                        Icons.calendar_month,
                      ),
                      label: Text(today),
                    ),
                  ),
                  IconButton(
                    onPressed: DateUtils.isSameDay(
                      selectedDate,
                      DateTime.now(),
                    )
                        ? null
                        : () => moveDay(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              if (page == 0) ...[
                statCards(width),
                const SizedBox(height: 13),
                twoColumns(
                  mealForm(),
                  foodForm(),
                  width,
                ),
                const SizedBox(height: 13),
                twoColumns(
                  mealHistory(),
                  chart(),
                  width,
                ),
              ] else if (page == 1)
                mealForm()
              else if (page == 2)
                  foodForm()
                else if (page == 3)
                    foodCatalog()
                  else if (page == 4)
                      mealHistory()
                    else if (page == 5)
                        chart()
                      else
                        AdvancedScreen(
                          key: ValueKey(page),
                          api: widget.api,
                          section: page - 6,
                          date: today,
                          foods: foods,
                          onChanged: refresh,
                        ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Dashboard',
      'Add Meal',
      'Add Food',
      'Food Database',
      'Meal History',
      'Nutrition Report',
      'Weekly / Monthly',
      'Nutrition Goals',
      'Water Tracker',
      'Profile & Settings',
      'Favorites',
      'RAG Recipe Chat',
    ];

    const icons = [
      Icons.dashboard_outlined,
      Icons.add_circle_outline,
      Icons.eco_outlined,
      Icons.storage_outlined,
      Icons.history,
      Icons.pie_chart_outline,
      Icons.bar_chart,
      Icons.flag_outlined,
      Icons.water_drop_outlined,
      Icons.person_outline,
      Icons.favorite_border,
      Icons.smart_toy_outlined,
    ];

    final wide = MediaQuery.sizeOf(context).width >= 900;

    Widget navItem(int i) {
      return ListTile(
        selected: page == i,
        selectedTileColor: const Color(0xFFE3F3E8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Icon(
          icons[i],
          color: page == i ? green : ink,
        ),
        title: Text(labels[i]),
        onTap: () {
          setState(() => page = i);
          if (!wide) {
            Navigator.pop(context);
          }
        },
      );
    }

    Widget navigation() {
      return SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Padding(
              padding: EdgeInsets.only(
                left: 12,
                top: 12,
                bottom: 24,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.spa,
                    color: green,
                    size: 30,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'FoodWise',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
            ...List.generate(
              labels.length,
              navItem,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.logout,
                color: Colors.redAccent,
              ),
              title: const Text('Logout'),
              onTap: widget.onLogout,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: wide
            ? const SizedBox.shrink()
            : const Text('FoodWise'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: Color(0xFFDEF4E4),
              child: Icon(
                Icons.person,
                color: green,
              ),
            ),
          ),
        ],
      ),
      drawer: wide
          ? null
          : Drawer(child: navigation()),
      body: Row(
        children: [
          if (wide)
            SizedBox(
              width: 250,
              child: ColoredBox(
                color: Colors.white,
                child: navigation(),
              ),
            ),
          Expanded(
            child: content(
              MediaQuery.sizeOf(context).width -
                  (wide ? 250 : 0),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.parts, this.colors);

  final List<double> parts;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(
      7,
      7,
      size.width - 14,
      size.height - 14,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;

    final total = parts.fold<double>(
      0,
          (a, b) => a + b,
    );

    paint.color = const Color(0xFFE8EEE8);
    canvas.drawArc(
      r,
      0,
      2 * math.pi,
      false,
      paint,
    );

    if (total <= 0) return;

    var start = -math.pi / 2;

    for (var i = 0; i < parts.length; i++) {
      final sweep =
          2 * math.pi * parts[i] / total;

      paint.color = colors[i];

      canvas.drawArc(
        r,
        start,
        sweep,
        false,
        paint,
      );

      start += sweep;
    }
  }

  @override
  bool shouldRepaint(
      covariant _DonutPainter old,
      ) {
    return true;
  }
}
