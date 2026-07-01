import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/ligand.dart';

class ProteinViewerScreen extends StatefulWidget {
  final Ligand ligand;
  const ProteinViewerScreen({super.key, required this.ligand});
  @override
  State<ProteinViewerScreen> createState() => _ProteinViewerScreenState();
}

class _ProteinViewerScreenState extends State<ProteinViewerScreen> {
  late final WebViewController _controller;
  bool _isLoaded = false;
  String? _selectedAtomInfo;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('AtomInfo', onMessageReceived: (msg) {
        try {
          final data = jsonDecode(msg.message) as Map<String, dynamic>;
          if (mounted) setState(() => _selectedAtomInfo = '${data['element']} · ${data['atomId']}');
        } catch (_) {}
      })
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (_) => _injectLigandData()))
      ..loadFlutterAsset('assets/viewer.html');
  }

  Map<String, dynamic> _ligandToJson() => {
    'id': widget.ligand.id,
    'name': widget.ligand.name ?? widget.ligand.id,
    'formula': widget.ligand.formula ?? '',
    'atoms': widget.ligand.atoms
        .map((a) => {
      'atomId': a.id,
      'element': a.element,
      'x': a.x,
      'y': a.y,
      'z': a.z,
    })
        .toList(),
    'bonds': widget.ligand.bonds
        .map((b) => {
      'atom1Id': b.atom1Id,
      'atom2Id': b.atom2Id,
      'bondOrder': b.order,
    })
        .toList(),
  };

  Future<void> _injectLigandData() async {
    final json = jsonEncode(_ligandToJson());
    final escaped = json.replaceAll('\\', '\\\\').replaceAll("'", "\\'");
    await _controller.runJavaScript("loadLigand('$escaped')");
    if (mounted) setState(() => _isLoaded = true);
  }

  Future<void> _shareScreenshot() async {
    try {
      final result = await _controller.runJavaScriptReturningResult('getScreenshot()');
      final dataUrl = result.toString().replaceAll('"', '');
      if (!dataUrl.startsWith('data:image/png;base64,')) {
        _showSnackbar('Could not capture screenshot.');
        return;
      }
      final bytes = base64Decode(dataUrl.split(',')[1]);
      final tmpPath = '${Directory.systemTemp.path}/${widget.ligand.id}.png';
      await File(tmpPath).writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(tmpPath)],
        text: '${widget.ligand.id} — ${widget.ligand.atomCount} atoms\nVisualized with Swifty Protein 🔬',
      );
    } catch (_) {
      _showSnackbar('Share failed. Please try again.');
    }
  }

  void _showSnackbar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF1A1A2E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Map<String, int> get _atomCounts {
    final counts = <String, int>{};
    for (final a in widget.ligand.atoms) {
      counts[a.element] = (counts[a.element] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final formula = widget.ligand.formula ?? '';
    final name = widget.ligand.name ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
          tooltip: 'Back to ligand list',
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.ligand.id,
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
            if (formula.isNotEmpty)
              Text(formula, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Color(0xFF00D4FF)),
            tooltip: 'Share screenshot',
            onPressed: _isLoaded ? _shareScreenshot : null,
          ),
        ],
      ),
      body: Stack(children: [
        Semantics(
          label: '3D model of ${widget.ligand.id}, ${widget.ligand.atomCount} atoms. '
              'Drag with one finger to rotate, pinch to zoom, two fingers to pan.',
          child: WebViewWidget(controller: _controller),
        ),
        if (!_isLoaded)
          Container(
            color: const Color(0xFF0D0D1A),
            child: const Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                CircularProgressIndicator(color: Color(0xFF00D4FF), strokeWidth: 2.5),
                SizedBox(height: 16),
                Text('Building 3D model...', style: TextStyle(color: Colors.white54)),
              ]),
            ),
          ),
        if (_isLoaded) Positioned(bottom: 0, left: 0, right: 0, child: _buildInfoPanel(name)),
        if (_selectedAtomInfo != null && _isLoaded)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () => setState(() => _selectedAtomInfo = null),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D4FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_selectedAtomInfo!,
                        style: const TextStyle(
                            color: Color(0xFF00D4FF), fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(width: 8),
                    const Icon(Icons.close, color: Color(0xFF00D4FF), size: 14),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildInfoPanel(String name) {
    final sorted = _atomCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withOpacity(0.95),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Text('${widget.ligand.atomCount} atoms · ${widget.ligand.bondCount} bonds',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            const Spacer(),
            if (name.isNotEmpty && name != widget.ligand.id)
              Flexible(
                child: Text(name,
                    style: const TextStyle(
                        color: Color(0xFF00D4FF), fontSize: 12, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: sorted.take(8).map((e) => _ElementChip(element: e.key, count: e.value)).toList(),
          ),
        ],
      ),
    );
  }
}

class _ElementChip extends StatelessWidget {
  final String element;
  final int count;
  const _ElementChip({required this.element, required this.count});

  Color get _color {
    const colors = {
      'C': Color(0xFF606060), 'H': Color(0xFFFFFFFF), 'O': Color(0xFFFF4444),
      'N': Color(0xFF4466FF), 'S': Color(0xFFFFFF44), 'P': Color(0xFFFF8800),
      'F': Color(0xFF90E050), 'CL': Color(0xFF1FF01F), 'BR': Color(0xFFA62929),
    };
    return colors[element.toUpperCase()] ?? const Color(0xFFFF69B4);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withOpacity(0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: _color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$element × $count', style: const TextStyle(color: Colors.white, fontSize: 11)),
      ]),
    );
  }
}