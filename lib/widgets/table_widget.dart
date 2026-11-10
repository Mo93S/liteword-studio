import 'package:flutter/material.dart';

import '../models/blocks.dart';
import 'paragraph_field.dart';

class TableWidget extends StatelessWidget {
  const TableWidget({super.key, required this.table, required this.docRtl});
  final TableBlock table;
  final bool docRtl;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: docRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Table(
          border: table.borderWidth <= 0
              ? null
              : TableBorder.all(color: Color(table.borderColor), width: table.borderWidth),
          children: [
            for (final row in table.cells)
              TableRow(children: [
                for (final cell in row)
                  Container(
                    key: ValueKey(cell.para.id),
                    color: cell.bg == null ? null : Color(cell.bg!),
                    padding: const EdgeInsets.all(6),
                    child: ParagraphField(para: cell.para, docRtl: docRtl, inCell: true),
                  )
              ])
          ],
        ),
      ),
    );
  }
}
