import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:go_router/go_router.dart';
import 'package:delwaqty/core/module/feature_module.dart';
import 'package:delwaqty/shared/widgets/app_shell.dart';

class FeatureRegistry {
  FeatureRegistry._();

  static final FeatureRegistry instance = FeatureRegistry._();

  final List<FeatureModule> _modules = [];
  bool _frozen = false;

  void register(FeatureModule module) {
    assert(!_frozen, 'Cannot register after freeze');
    assert(
      !_modules.any((m) => m.id == module.id),
      'Duplicate module id: ${module.id}',
    );
    _modules.add(module);
  }

  void registerAll(List<FeatureModule> modules) {
    for (final m in modules) {
      register(m);
    }
  }

  void freeze() {
    assert(!_frozen, 'Already frozen');
    _resolveDependencies();
    _assignShellIndices();
    _frozen = true;
  }

  List<FeatureModule> get modules => List.unmodifiable(_modules);

  List<FeatureModule> get navModules =>
      _modules.where((m) => m.isNavModule).toList()
        ..sort((a, b) => a.navPriority.compareTo(b.navPriority));

  List<RouteBase> get allStandaloneRoutes =>
      _modules.expand((m) => m.standaloneRoutes).toList();

  List<RouteBase> get allShellSubRoutes =>
      _modules.expand((m) => m.shellSubRoutes).toList();

  List<DrawerEntry> get allDrawerEntries {
    final entries = <DrawerEntry>[];
    for (final m in _modules) {
      entries.addAll(m.drawerEntries);
    }
    entries.sort((a, b) => a.position.index.compareTo(b.position.index));
    return entries;
  }

  List<Override> collectOverrides(Ref ref) =>
      _modules.expand((m) => m.providerOverrides(ref)).toList();

  StatefulShellRoute buildShellRoute() {
    return StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: navModules.map((m) => m.buildBranch()!).toList(),
    );
  }

  void _resolveDependencies() {
    final visited = <String>{};
    final visiting = <String>{};
    final sorted = <FeatureModule>[];

    void visit(FeatureModule module) {
      if (visited.contains(module.id)) return;
      if (visiting.contains(module.id)) {
        throw StateError('Circular dependency detected: ${module.id}');
      }
      visiting.add(module.id);
      for (final depId in module.dependsOn) {
        final dep = _modules.where((m) => m.id == depId).firstOrNull;
        if (dep != null) visit(dep);
      }
      visiting.remove(module.id);
      visited.add(module.id);
      sorted.add(module);
    }

    for (final m in _modules) {
      visit(m);
    }

    _modules
      ..clear()
      ..addAll(sorted);
  }

  void _assignShellIndices() {
    var index = 0;
    for (final m in navModules) {
      _shellIndices[m.id] = index;
      index++;
    }
  }

  final Map<String, int> _shellIndices = {};

  int shellIndexFor(String moduleId) => _shellIndices[moduleId] ?? 0;
}
