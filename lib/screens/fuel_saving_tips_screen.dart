import 'package:flutter/material.dart';
import '../widgets/gasmaster_brand.dart';

class FuelSavingTip {
  final IconData icon;
  final String title;
  final String body;

  const FuelSavingTip({
    required this.icon,
    required this.title,
    required this.body,
  });
}

/// Practical, driver-controllable habits that improve fuel economy.
const fuelSavingTips = <FuelSavingTip>[
  FuelSavingTip(
    icon: Icons.tire_repair_outlined,
    title: 'Keep tires at the right pressure',
    body:
        'Under-inflated tires raise rolling resistance and waste fuel. '
        'Check pressure when tires are cold and match the placard on the door jamb.',
  ),
  FuelSavingTip(
    icon: Icons.trending_up,
    title: 'Accelerate smoothly',
    body:
        'Hard launches burn extra fuel. Ease into the throttle and let the '
        'engine build speed gradually.',
  ),
  FuelSavingTip(
    icon: Icons.speed_outlined,
    title: 'Brake early, not hard',
    body:
        'Anticipate stops so you can coast down instead of slamming the brakes. '
        'Every hard stop throws away the energy you just used to accelerate.',
  ),
  FuelSavingTip(
    icon: Icons.straight,
    title: 'Hold a steady highway speed',
    body:
        'Fuel use rises sharply above about 50–60 mph. Use cruise control on '
        'flat, open roads when it is safe to do so.',
  ),
  FuelSavingTip(
    icon: Icons.luggage_outlined,
    title: 'Drop unused weight and roof cargo',
    body:
        'Extra mass and roof racks increase drag. Clear the trunk of items you '
        'do not need, and remove roof boxes or bikes when you are not using them.',
  ),
  FuelSavingTip(
    icon: Icons.route_outlined,
    title: 'Combine short trips',
    body:
        'A cold engine uses more fuel. Bundle errands into one outing so the '
        'engine stays warm instead of restarting for every short hop.',
  ),
  FuelSavingTip(
    icon: Icons.timer_off_outlined,
    title: 'Idle less',
    body:
        'Idling burns fuel and gets you nowhere. If you will be stopped more '
        'than about 30 seconds (and it is safe), turn the engine off.',
  ),
  FuelSavingTip(
    icon: Icons.air,
    title: 'Windows vs. A/C at speed',
    body:
        'At city speeds, open windows are often fine. On the highway, open '
        'windows add drag — A/C or climate control is usually the more efficient choice.',
  ),
  FuelSavingTip(
    icon: Icons.local_gas_station_outlined,
    title: 'Use the recommended octane',
    body:
        'Premium does not improve mileage unless your vehicle requires it. '
        'Follow the owner’s manual; higher octane is not a free efficiency boost.',
  ),
  FuelSavingTip(
    icon: Icons.filter_alt_outlined,
    title: 'Keep the air filter in good shape',
    body:
        'A clogged filter can hurt efficiency. Check it on the schedule in your '
        'manual, or have it inspected at a routine service visit.',
  ),
  FuelSavingTip(
    icon: Icons.visibility_outlined,
    title: 'Look ahead and coast',
    body:
        'Watch traffic farther down the road. Lifting early for lights, hills, '
        'and slowdowns lets you cover more distance without burning fuel.',
  ),
];

class FuelSavingTipsScreen extends StatelessWidget {
  const FuelSavingTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const GasMasterAppBarTitle(subtitle: 'Fuel-Saving Tips'),
        centerTitle: false,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: fuelSavingTips.length + 1,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'Habits you can use on every drive to stretch a tank farther.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          final tip = fuelSavingTips[index - 1];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Icon(
              tip.icon,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              tip.title,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(tip.body),
            ),
            isThreeLine: true,
          );
        },
      ),
    );
  }
}
