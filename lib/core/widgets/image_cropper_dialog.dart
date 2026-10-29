import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Opens a modern modal dialog allowing the user to crop, zoom, and select
/// standard aspect ratios for the provided image bytes.
Future<Uint8List?> showImageCropper(
    BuildContext context, Uint8List imageBytes) {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => ImageCropperDialog(imageBytes: imageBytes),
  );
}

class ImageCropperDialog extends StatefulWidget {
  const ImageCropperDialog({super.key, required this.imageBytes});
  final Uint8List imageBytes;

  @override
  State<ImageCropperDialog> createState() => _ImageCropperDialogState();
}

class _ImageCropperDialogState extends State<ImageCropperDialog> {
  final _controller = CropController();
  double? _aspectRatio;
  bool _cropping = false;

  void _onCropPressed() {
    setState(() => _cropping = true);
    _controller.crop();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dialogWidth = (size.width * 0.9).clamp(320.0, 720.0);
    final dialogHeight = (size.height * 0.85).clamp(400.0, 700.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              color: AppColors.navy,
              child: Row(
                children: [
                  const Icon(Icons.crop, color: AppColors.gold, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Crop Image',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    tooltip: 'Cancel',
                    onPressed:
                        _cropping ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Cropper area
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Colors.black,
                    child: Crop(
                      image: widget.imageBytes,
                      controller: _controller,
                      aspectRatio: _aspectRatio,
                      interactive: true,
                      baseColor: Colors.black,
                      maskColor: Colors.black.withAlpha((0.6 * 255).round()),
                      radius: 8,
                      onCropped: (result) {
                        setState(() => _cropping = false);
                        switch (result) {
                          case CropSuccess(:final croppedImage):
                            Navigator.of(context).pop(croppedImage);
                            break;
                          case CropFailure(:final cause):
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Cropping failed: $cause')),
                            );
                            break;
                        }
                      },
                    ),
                  ),
                  if (_cropping)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: AppColors.gold),
                            SizedBox(height: 14),
                            Text(
                              'Cropping image...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Aspect Ratio Toolbar & Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Aspect Ratio:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _RatioChip(
                          label: 'Free',
                          selected: _aspectRatio == null,
                          onSelected: () {
                            setState(() {
                              _aspectRatio = null;
                              _controller.aspectRatio = null;
                            });
                          },
                        ),
                        const SizedBox(width: 6),
                        _RatioChip(
                          label: '1:1',
                          selected: _aspectRatio == 1.0,
                          onSelected: () {
                            setState(() {
                              _aspectRatio = 1.0;
                              _controller.aspectRatio = 1.0;
                            });
                          },
                        ),
                        const SizedBox(width: 6),
                        _RatioChip(
                          label: '4:3',
                          selected: _aspectRatio == 4.0 / 3.0,
                          onSelected: () {
                            setState(() {
                              _aspectRatio = 4.0 / 3.0;
                              _controller.aspectRatio = 4.0 / 3.0;
                            });
                          },
                        ),
                        const SizedBox(width: 6),
                        _RatioChip(
                          label: '16:9',
                          selected: _aspectRatio == 16.0 / 9.0,
                          onSelected: () {
                            setState(() {
                              _aspectRatio = 16.0 / 9.0;
                              _controller.aspectRatio = 16.0 / 9.0;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _cropping
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: _cropping ? null : _onCropPressed,
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Apply Crop'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatioChip extends StatelessWidget {
  const _RatioChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? Colors.white : AppColors.ink,
      ),
      selectedColor: AppColors.navy,
      backgroundColor: AppColors.canvas,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      side: BorderSide(color: selected ? AppColors.navy : AppColors.line),
    );
  }
}
