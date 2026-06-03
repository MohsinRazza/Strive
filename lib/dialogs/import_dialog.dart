import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design_system.dart';

/// Shows the import session history dialog.
/// [onImport] receives raw JSON text and returns true on success.
void showImportDialog({
  required BuildContext context,
  required AppColors colors,
  required Future<bool> Function(String jsonText) onImport,
}) {
  final pathController = TextEditingController();

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
              'Import Session History',
              style: AppDesign.getAppHeaderStyle(colors).copyWith(fontSize: 18),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Import a Strive session backup. This will merge sessions and prevent duplicate entries automatically.',
                  style: AppDesign.getLogFeedStyle(colors)
                      .copyWith(color: colors.muted),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final clipboardData =
                        await Clipboard.getData(Clipboard.kTextPlain);
                    final text = clipboardData?.text ?? '';
                    if (text.trim().isEmpty) {
                      setDialogState(() {
                        statusMessage =
                            '❌ Clipboard is empty or contains no text.';
                      });
                      return;
                    }
                    final success = await onImport(text);
                    setDialogState(() {
                      statusMessage = success
                          ? '✅ Successfully imported & merged data!'
                          : '❌ Invalid format. Please check JSON data.';
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
                  icon: const Icon(Icons.paste_rounded, size: 16),
                  label: const Text(
                    'Paste & Import from Clipboard',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Load from Local File Path:',
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
                      if (!await file.exists()) {
                        setDialogState(() {
                          statusMessage =
                              '❌ File does not exist at this path.';
                        });
                        return;
                      }
                      final text = await file.readAsString();
                      final success = await onImport(text);
                      setDialogState(() {
                        statusMessage = success
                            ? '✅ Successfully imported & merged file data!'
                            : '❌ Invalid format. Please check JSON file content.';
                      });
                    } catch (e) {
                      setDialogState(() {
                        statusMessage =
                            '❌ Error reading file:\n${e.toString()}';
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
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text(
                    'Load & Import from File',
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
