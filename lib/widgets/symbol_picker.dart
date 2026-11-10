import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/editor_controller.dart';

const Map<String, String> kSymbolGroups = {
  'كيمياء': '→ ⇌ ⇄ ⇋ ↑ ↓ ⟶ ⟵ ⇒ ⇔ ⁺ ⁻ ²⁺ ³⁺ ²⁻ ³⁻ ° Δ · ‰ ± ≈ ≠ ∝ ℃ ⏚',
  'رياضيات': '√ ∛ ∜ ∫ ∬ ∭ ∮ ∑ ∏ ± ∓ × ÷ ≠ ≈ ≡ ≤ ≥ ≪ ≫ ∞ ∂ ∇ ∈ ∉ ⊂ ⊃ ⊆ ∪ ∩ ∅ ∴ ∵ ∠ ⊥ ∥ ∀ ∃ ¼ ½ ¾ ′ ″ ⁄ ℃ ℉ π',
  'يونانية': 'α β γ δ ε ζ η θ ι κ λ μ ν ξ ο π ρ σ τ υ φ χ ψ ω Α Β Γ Δ Ε Ζ Η Θ Ι Κ Λ Μ Ν Ξ Ο Π Ρ Σ Τ Υ Φ Χ Ψ Ω',
  'أسهم': '← ↑ → ↓ ↔ ↕ ⇐ ⇑ ⇒ ⇓ ⇔ ↦ ↩ ↪ ⟵ ⟶ ⟷',
  'أُسس': '⁰ ¹ ² ³ ⁴ ⁵ ⁶ ⁷ ⁸ ⁹ ⁺ ⁻ ⁼ ⁽ ⁾ ⁿ ₀ ₁ ₂ ₃ ₄ ₅ ₆ ₇ ₈ ₉ ₊ ₋ ₌ ₍ ₎',
};

Future<void> showSymbolPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => const SymbolPicker(),
  );
}

class SymbolPicker extends StatelessWidget {
  const SymbolPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final ed = context.read<EditorController>();
    final keys = kSymbolGroups.keys.toList();
    return SizedBox(
      height: 320,
      child: DefaultTabController(
        length: keys.length,
        child: Column(children: [
          TabBar(isScrollable: true, tabs: [for (final k in keys) Tab(text: k, height: 34)]),
          Expanded(
            child: TabBarView(children: [
              for (final k in keys)
                GridView.extent(
                  maxCrossAxisExtent: 52,
                  padding: const EdgeInsets.all(8),
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  children: [
                    for (final s in kSymbolGroups[k]!.split(' ').where((e) => e.isNotEmpty))
                      InkWell(
                        canRequestFocus: false,
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => ed.insertSymbol(s),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).dividerColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(s, style: const TextStyle(fontSize: 20)),
                        ),
                      ),
                  ],
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
