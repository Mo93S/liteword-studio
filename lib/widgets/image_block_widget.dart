import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/editor_controller.dart';
import '../models/blocks.dart';

/// Image with aspect-ratio lock, alignment and size controls (shown when selected).
class ImageBlockWidget extends StatelessWidget {
  const ImageBlockWidget({super.key, required this.image});
  final ImageBlock image;

  @override
  Widget build(BuildContext context) {
    final ed = context.read<EditorController>();
    final selected = identical(ed.activeImage, image);
    final cs = Theme.of(context).colorScheme;
    final maxW = ed.contentWidth;
    final al = image.align == TextAlign.left
        ? Alignment.centerLeft
        : image.align == TextAlign.right
            ? Alignment.centerRight
            : Alignment.center;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: al,
            child: GestureDetector(
              onTap: () => ed.selectImage(image),
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: selected ? cs.primary : Colors.transparent, width: 2)),
                child: Image.memory(
                  image.bytes,
                  width: image.w,
                  height: image.h,
                  fit: BoxFit.fill,
                  cacheWidth: (image.w * 2).round().clamp(50, 2400).toInt(),
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
          if (selected)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
              child: Column(children: [
                Row(children: [
                  IconButton(
                    tooltip: image.lock ? 'إلغاء قفل النسبة' : 'قفل النسبة',
                    icon: Icon(image.lock ? Icons.lock : Icons.lock_open, size: 20),
                    onPressed: () => ed.imageLock(image, !image.lock),
                  ),
                  IconButton(
                      tooltip: 'يمين',
                      icon: const Icon(Icons.format_align_right, size: 20),
                      onPressed: () => ed.imageAlign(image, TextAlign.right)),
                  IconButton(
                      tooltip: 'وسط',
                      icon: const Icon(Icons.format_align_center, size: 20),
                      onPressed: () => ed.imageAlign(image, TextAlign.center)),
                  IconButton(
                      tooltip: 'يسار',
                      icon: const Icon(Icons.format_align_left, size: 20),
                      onPressed: () => ed.imageAlign(image, TextAlign.left)),
                  const Spacer(),
                  Text('${image.w.round()}×${image.h.round()}', style: const TextStyle(fontSize: 12)),
                  IconButton(
                    tooltip: 'حذف الصورة',
                    icon: Icon(Icons.delete_outline, size: 20, color: cs.error),
                    onPressed: () => ed.deleteImage(image),
                  ),
                ]),
                Row(children: [
                  const Text('العرض', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: image.w.clamp(40, maxW).toDouble(),
                      min: 40,
                      max: maxW,
                      onChanged: (v) => ed.imageSize(image, w: v),
                    ),
                  ),
                ]),
                if (!image.lock)
                  Row(children: [
                    const Text('الارتفاع', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: image.h.clamp(40, 1000).toDouble(),
                        min: 40,
                        max: 1000,
                        onChanged: (v) => ed.imageSize(image, h: v),
                      ),
                    ),
                  ]),
              ]),
            ),
        ],
      ),
    );
  }
}
