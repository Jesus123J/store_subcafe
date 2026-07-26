import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_async_value.dart';
import '../../../../shared/widgets/app_data_table.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../auth/data/models/usuario_model.dart';
import '../../../auth/domain/entities/usuario.dart';
import '../providers/usuarios_provider.dart';
import '../widgets/usuario_form_dialog.dart';

class UsuariosPage extends ConsumerStatefulWidget {
  const UsuariosPage({super.key});

  @override
  ConsumerState<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends ConsumerState<UsuariosPage> {
  final _busquedaCtrl = TextEditingController();

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usuariosAsync = ref.watch(usuariosListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppPageHeader(
            title: 'Usuarios',
            subtitle: 'Vendedores, Encargados y Administradores del sistema',
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                onPressed: () => ref.invalidate(usuariosListProvider),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _abrirFormulario(context, ref, null),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo usuario'),
              ),
            ],
          ),
          Expanded(
            child: AppAsyncView<List<UsuarioModel>>(
              value: usuariosAsync,
              onRetry: () => ref.invalidate(usuariosListProvider),
              dataBuilder: (lista) {
                if (lista.isEmpty) {
                  return AppEmptyState(
                    message: 'Aún no hay usuarios registrados',
                    icon: Icons.people_outline,
                    actionLabel: 'Crear el primero',
                    onAction: () => _abrirFormulario(context, ref, null),
                  );
                }
                return _Body(
                  usuarios: lista,
                  busquedaCtrl: _busquedaCtrl,
                  onSearchChange: () => setState(() {}),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirFormulario(
    BuildContext context,
    WidgetRef ref,
    UsuarioModel? usuario,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => UsuarioFormDialog(usuario: usuario),
    );
    if (result == true && context.mounted) {
      context.showSnack(
        usuario == null ? 'Usuario creado' : 'Usuario actualizado',
      );
    }
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.usuarios,
    required this.busquedaCtrl,
    required this.onSearchChange,
  });

  final List<UsuarioModel> usuarios;
  final TextEditingController busquedaCtrl;
  final VoidCallback onSearchChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = busquedaCtrl.text.toLowerCase();
    final filtrados = q.isEmpty
        ? usuarios
        : usuarios.where((u) {
            return u.username.toLowerCase().contains(q) ||
                u.nombreCompleto.toLowerCase().contains(q);
          }).toList();

    final admins = usuarios
        .where((u) => u.rol == RolUsuario.administrador)
        .length;
    final activos = usuarios.where((u) => u.activo).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: AppStatTile(
                  icon: Icons.people,
                  label: 'Total usuarios',
                  value: '${usuarios.length}',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppStatTile(
                  icon: Icons.admin_panel_settings,
                  label: 'Administradores',
                  value: '$admins',
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppStatTile(
                  icon: Icons.check_circle_outline,
                  label: 'Activos',
                  value: '$activos',
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: AppDataTable(
              searchController: busquedaCtrl,
              onSearchChanged: onSearchChange,
              searchHint: 'Buscar por usuario o nombre...',
              totalItems: usuarios.length,
              filteredItems: filtrados.length,
              emptyMessage: 'No hay usuarios que coincidan con la búsqueda',
              columns: const [
                AppTableColumn(label: 'Usuario', width: 140),
                AppTableColumn(label: 'Nombre completo', flex: 3),
                AppTableColumn(label: 'Rol', width: 140),
                AppTableColumn(label: 'Estado', width: 100),
                AppTableColumn(
                    label: 'Acciones', width: 100, align: TextAlign.right),
              ],
              rows: filtrados
                  .map((u) => AppTableRow(
                        cells: [
                          Text(
                            u.username,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            u.nombreCompleto,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          _rolBadge(u.rol),
                          AppBadge(
                            label: u.activo ? 'Activo' : 'Inactivo',
                            color: u.activo
                                ? AppColors.secondary
                                : AppColors.textSecondary,
                          ),
                          _AccionesRow(usuario: u),
                        ],
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rolBadge(RolUsuario rol) {
    final (label, color) = switch (rol) {
      RolUsuario.administrador => ('Administrador', AppColors.primary),
      RolUsuario.encargado => ('Encargado', AppColors.info),
      RolUsuario.vendedor => ('Vendedor', AppColors.secondary),
    };
    return AppBadge(label: label, color: color);
  }
}

class _AccionesRow extends ConsumerWidget {
  const _AccionesRow({required this.usuario});
  final UsuarioModel usuario;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined,
              size: 18, color: AppColors.primary),
          tooltip: 'Editar',
          visualDensity: VisualDensity.compact,
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (_) => UsuarioFormDialog(usuario: usuario),
            );
            if (ok == true && context.mounted) {
              context.showSnack('Usuario actualizado');
            }
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline,
              size: 18, color: AppColors.error),
          tooltip: 'Desactivar',
          visualDensity: VisualDensity.compact,
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (dialogCtx) => AlertDialog(
                title: const Text('Desactivar usuario'),
                content: Text(
                    '¿Estás seguro de desactivar a ${usuario.username}?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(true),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error),
                    child: const Text('Desactivar'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              try {
                await ref
                    .read(usuariosControllerProvider)
                    .eliminar(usuario.id);
                if (context.mounted) context.showSnack('Usuario desactivado');
              } catch (e) {
                if (context.mounted) {
                  context.showSnack(e.toString(), isError: true);
                }
              }
            }
          },
        ),
      ],
    );
  }
}
