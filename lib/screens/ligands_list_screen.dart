import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/ligand_service.dart';
import '../utils/app_theme.dart';
import 'login_screen.dart';
import 'protein_viewer_screen.dart';

class LigandsListScreen extends StatefulWidget {
  const LigandsListScreen({super.key});

  @override
  State<LigandsListScreen> createState() => _LigandsListScreenState();
}

class _LigandsListScreenState extends State<LigandsListScreen> {
  final _service = LigandService();
  final _auth = AuthService();
  final _searchCtrl = TextEditingController();

  List<String> _allLigands = [];
  List<String> _filtered = [];
  bool _loadingList = true;
  String? _loadingLigand; // ID currently being fetched
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
    _loadList();
  }

  Future<void> _loadList() async {
    try {
      final list = await _service.loadLigandList();
      setState(() { _allLigands = list; _filtered = list; _loadingList = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load ligand list.'; _loadingList = false; });
    }
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toUpperCase();
    setState(() {
      _filtered = q.isEmpty
          ? _allLigands
          : _allLigands.where((l) => l.toUpperCase().contains(q)).toList();
    });
  }

  Future<void> _selectLigand(String id) async {
    if (_loadingLigand != null) return;
    setState(() => _loadingLigand = id);

    try {
      final ligand = await _service.fetchLigand(id);
      if (!mounted) return;
      setState(() => _loadingLigand = null);
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => ProteinViewerScreen(ligand: ligand)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingLigand = null);
      _showError(e.toString());
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: AppTheme.error),
          SizedBox(width: 10),
          Text('Error', style: TextStyle(color: AppTheme.onSurface)),
        ]),
        content: Text(msg, style: const TextStyle(color: AppTheme.onSurfaceDim)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: AppTheme.primary))),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('PROTEIN LIBRARY'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.onSurfaceDim),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Semantics(
              label: 'Search ligands by ID',
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: AppTheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'Search ligands...',
                  prefixIcon: const Icon(Icons.search, color: AppTheme.onSurfaceDim),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppTheme.onSurfaceDim),
                          tooltip: 'Clear search',
                          onPressed: () { _searchCtrl.clear(); })
                      : null,
                ),
              ),
            ),
          ),
          // Count
          if (!_loadingList)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                Text('${_filtered.length} ligands',
                    style: const TextStyle(color: AppTheme.onSurfaceDim, fontSize: 12, letterSpacing: 0.5)),
              ]),
            ),
          // List
          Expanded(
            child: _loadingList
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.error)))
                    : _filtered.isEmpty
                        ? const Center(child: Text('No ligands found.', style: TextStyle(color: AppTheme.onSurfaceDim)))
                        : ListView.builder(
                            itemCount: _filtered.length,
                            itemExtent: 68,
                            itemBuilder: (ctx, i) => _LigandTile(
                              id: _filtered[i],
                              isLoading: _loadingLigand == _filtered[i],
                              onTap: () => _selectLigand(_filtered[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _LigandTile extends StatelessWidget {
  final String id;
  final bool isLoading;
  final VoidCallback onTap;

  const _LigandTile({required this.id, required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isLoading
          ? 'Ligand $id, loading'
          : 'Ligand $id, tap to visualize in 3D',
      button: true,
      enabled: !isLoading,
      excludeSemantics: true,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF1F2937), width: 1)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primary.withOpacity(0.12),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                ),
                child: const Icon(Icons.bubble_chart_rounded, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(id, style: const TextStyle(color: AppTheme.onSurface, fontWeight: FontWeight.w600, fontSize: 15)),
                    const Text('Tap to visualize in 3D', style: TextStyle(color: AppTheme.onSurfaceDim, fontSize: 12)),
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
              else
                const Icon(Icons.chevron_right, color: AppTheme.onSurfaceDim),
            ],
          ),
        ),
      ),
    );
  }
}
