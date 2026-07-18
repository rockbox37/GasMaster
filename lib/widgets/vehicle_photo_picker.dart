import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/vehicle_photo_service.dart';

typedef PhotoOptimizedCallback = void Function(ImageOptimizationResult result);

/// Picks a photo, optimizes it, shows savings, and notifies the parent.
class VehiclePhotoPicker extends StatefulWidget {
  final String? existingRelativePath;
  final PhotoOptimizedCallback? onOptimized;
  final VoidCallback? onRemoved;

  const VehiclePhotoPicker({
    super.key,
    this.existingRelativePath,
    this.onOptimized,
    this.onRemoved,
  });

  @override
  State<VehiclePhotoPicker> createState() => VehiclePhotoPickerState();
}

class VehiclePhotoPickerState extends State<VehiclePhotoPicker> {
  final _picker = ImagePicker();
  bool _optimizing = false;
  String? _status;
  Uint8List? _previewBytes;
  ImageOptimizationResult? lastResult;
  bool removed = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final rel = widget.existingRelativePath;
    if (rel == null || rel.isEmpty) return;
    final abs = await VehiclePhotoService.absolutePath(rel);
    final file = File(abs);
    if (await file.exists() && mounted) {
      final bytes = await file.readAsBytes();
      setState(() => _previewBytes = Uint8List.fromList(bytes));
    }
  }

  Future<void> _pick(ImageSource source) async {
    final x = await _picker.pickImage(source: source);
    if (x == null || !mounted) return;

    setState(() {
      _optimizing = true;
      _status = 'Optimizing photo to save storage…';
      removed = false;
    });

    try {
      final bytes = await File(x.path).readAsBytes();
      final result = VehiclePhotoService.optimizeBytes(Uint8List.fromList(bytes));
      if (!mounted) return;
      setState(() {
        lastResult = result;
        _previewBytes = result.bytes;
        _optimizing = false;
        _status = result.savingsSummary;
      });
      widget.onOptimized?.call(result);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _optimizing = false;
        _status = 'Could not optimize photo. Try another image.';
      });
    }
  }

  void _remove() {
    setState(() {
      lastResult = null;
      _previewBytes = null;
      _status = null;
      removed = true;
    });
    widget.onRemoved?.call();
  }

  void _showSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from library'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pick(ImageSource.camera);
              },
            ),
            if (_previewBytes != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Theme.of(ctx).colorScheme.error),
                title: Text('Remove photo', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                onTap: () {
                  Navigator.pop(ctx);
                  _remove();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Material(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _optimizing ? null : _showSourceSheet,
              child: _previewBytes != null
                  ? Image.memory(_previewBytes!, fit: BoxFit.cover)
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_a_photo_outlined, size: 40, color: theme.colorScheme.primary),
                            const SizedBox(height: 8),
                            Text('Add vehicle photo', style: theme.textTheme.titleSmall),
                            const SizedBox(height: 4),
                            Text(
                              'Optional — large photos are optimized automatically',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
        if (_optimizing || _status != null) ...[
          const SizedBox(height: 12),
          if (_optimizing)
            Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(_status ?? 'Optimizing…')),
              ],
            )
          else
            Text(
              _status!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ],
    );
  }
}
