import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../design_system.dart';
import '../session_storage.dart';

/// Shows the export session history dialog.
Future<void> showExportDialog({
  required BuildContext context,
  required AppColors colors,
}) async {
  final jsonStr = await SessionStorage.exportToJsonString();
  final pathController = TextEditingController();

  try {
    final docDir = await getApplicationDocumentsDirectory();
    pathController.text = '${docDir.path}/strive_backup.json';
  } catch (_) {}

  if (!context.mounted) return;

  showDialog<void>(
    context: context,
    builder: (context) {
      String statusMessage = '';
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: colors.card,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDesign.borderRadiusCard),
              side: BorderSide(color: colors.border, width: 1),
            ),
            title: Text(
              'Export Session History',
              style: AppDesign.getAppHeaderStyle(colors).copyWith(fontSize: 18),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backup your study sessions either by copying the data to your clipboard or saving to a local JSON file.',
                  style: AppDesign.getLogFeedStyle(colors)
                      .copyWith(color: colors.muted),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: jsonStr));
                    setDialogState(() {
                      statusMessage = '✅ JSON backup copied to clipboard!';
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary.withOpacity(0.08),
                    foregroundColor: colors.primary,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDesign.borderRadiusInput),
                      side: BorderSide(color: colors.border, width: 1),
                    ),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text(
                    'Copy JSON Data to Clipboard',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Save to Local File Path:',
                  style: AppDesign.getLogFeedStyle(colors)
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildPathTextField(colors, pathController),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final path = pathController.text.trim();
                    if (path.isEmpty) {
                      setDialogState(() {
                        statusMessage = '❌ Please enter a valid path.';
                      });
                      return;
                    }
                    try {
                      final file = File(path);
                      await file.parent.create(recursive: true);
                      await file.writeAsString(jsonStr);
                      setDialogState(() {
                        statusMessage = '✅ Saved successfully to:\n$path';
                      });
                    } catch (e) {
                      setDialogState(() {
                        statusMessage = '❌ Error writing file:\n${e.toString()}';
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDesign.borderRadiusInput),
                    ),
                  ),
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text(
                    'Save to Path',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (statusMessage.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    statusMessage,
                    style: AppDesign.getBodyMutedStyle(colors).copyWith(
                      color: statusMessage.contains('✅')
                          ? colors.focusAccent
                          : Colors.redAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child:
                    Text('Close', style: TextStyle(color: colors.foreground)),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _buildPathTextField(
    AppColors colors, TextEditingController controller) {
  return TextField(
    controller: controller,
    style: TextStyle(color: colors.foreground, fontSize: 13),
    decoration: InputDecoration(
      hintText: '/path/to/backup.json',
      hintStyle: TextStyle(color: colors.muted),
      filled: true,
      fillColor: colors.background,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDesign.borderRadiusInput),
        borderSide: BorderSide(color: colors.focusAccent),
      ),
    ),
  );
}
