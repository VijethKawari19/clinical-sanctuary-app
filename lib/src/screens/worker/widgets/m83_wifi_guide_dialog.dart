import 'package:flutter/material.dart';

/// Connection steps for M83 camera Wi‑Fi (Pillar 4).
Future<void> showM83WifiGuideDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.wifi_tethering_rounded,
              color: Theme.of(ctx).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            const Expanded(child: Text('Connect to M83')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _step(ctx, '1', 'Turn on the M83.'),
              _step(ctx, '2', 'Open your phone or tablet Wi‑Fi settings.'),
              _step(
                ctx,
                '3',
                'Connect to the camera network (name is usually similar to "m83xxxxxx").',
              ),
              _step(
                ctx,
                '4',
                'Password is often 88888888 (eight eights) unless you changed it.',
              ),
              _step(
                ctx,
                '5',
                'Return to this app, optionally set IP/port under Advanced, then tap Connect.',
              ),
              const SizedBox(height: 12),
              Text(
                'Tip: The camera often uses 192.168.1.1 on TCP port 40005. If video does not start, try ports 40001–40009.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      );
    },
  );
}

Widget _step(BuildContext context, String n, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            n,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(height: 1.35),
          ),
        ),
      ],
    ),
  );
}
