import 'package:flutter/material.dart';
import '../models/bus_data.dart';

class BusBottomSheet extends StatelessWidget {
  final bool isOnBus;
  final String? selectedBus;
  final Function(String) onBusSelected;
  final VoidCallback onExit;

  const BusBottomSheet({
    super.key,
    required this.isOnBus,
    required this.selectedBus,
    required this.onBusSelected,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFCC0000).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.directions_bus, color: Color(0xFFCC0000), size: 24),
              ),
              const SizedBox(width: 12),
              const Text('Select Your Bus', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 44),
              child: Text(
                isOnBus ? 'Currently on a bus. Tap another to switch, or exit.' : 'Choose the bus you\'re riding',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (isOnBus) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onExit,
                icon: const Icon(Icons.logout, color: Color(0xFFCC0000), size: 18),
                label: const Text('Exit Bus & Stop Sharing', style: TextStyle(color: Color(0xFFCC0000))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFCC0000)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
          ],
          SizedBox(
            height: 300,
            child: ListView.builder(
              itemCount: duBusRoutes.length,
              itemBuilder: (_, i) {
                final bus = duBusRoutes[i];
                final isSelected = bus.id == selectedBus;
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? const Color(0xFF1B2D1B) : const Color(0xFFF0FFF0))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: Colors.green.shade300)
                        : null,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.green.withValues(alpha: 0.1)
                            : const Color(0xFFCC0000).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.directions_bus,
                          color: isSelected ? Colors.green : const Color(0xFFCC0000),
                          size: 20),
                    ),
                    title: Text(bus.nameEn,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(bus.nameBn,
                        style: const TextStyle(fontSize: 12)),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.green, size: 22)
                        : Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
                    onTap: () => onBusSelected(bus.id),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
