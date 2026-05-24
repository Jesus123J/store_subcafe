import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../shared/widgets/app_async_value.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../auth/data/models/usuario_model.dart';
import '../../../auth/domain/entities/usuario.dart';
import '../providers/usuarios_provider.dart';
import '../widgets/usuario_form_dialog.dart';

class UsuariosPage extends ConsumerWidget {
  const UsuariosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuariosAsync = ref.watch(usuariosListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppPageHeader(
            title: 'Usuarios',
            subtitle: 'Vendedores, Encargados y Administradores del sistema',
            actions: [
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
                return AppCard(
                  child: _UsuariosTable(usuarios: lista, ref: ref),
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

class _UsuariosTable extends StatelessWidget {
  const _UsuariosTable({required this.usuarios, required this.ref});
  final List<UsuarioModel> usuarios;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: DataTable(
        columnSpacing: 24,
        headingRowColor: WidgetStateProperty.all(AppColors.background),
        columns: const [
          DataColumn(label: Text('Usuario')),
          DataColumn(label: Text('Nombre completo')),
          DataColumn(label: Text('Rol')),
          DataColumn(label: Text('Estado')),
          DataColumn(label: Text('Acciones')),
        ],
        rows: usuarios.map((u) {
          return DataRow(
            cells: [
              DataCell(Text(u.username, style: const TextStyle(fontWeight: FontWeight.w500))),
              DataCell(Text(u.nombreCompleto)),
              DataCell(_RolChip(rol: u.rol)),
              DataCell(_EstadoChip(activo: u.activo)),
              DataCell(_AccionesRow(usuario: u, refWidget: ref)),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _RolChip extends StatelessWidget {
  const _RolChip({required this.rol});
  final RolUsuario rol;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (rol) {
      RolUsuario.administrador => ('Administrador', AppColors.primary),
      RolUsuario.encargado => ('Encargado', AppColors.info),
      RolUsuario.vendedor => ('Vendedor', AppColors.secondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EstadoChip extends StatelessWidget {
  const _EstadoChip({required this.activo});
  final bool activo;

  @override
  Widget build(BuildContext context) {
    final color = activo ? AppColors.secondary : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        activo ? 'Activo' : 'Inactivo',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _AccionesRow extends ConsumerWidget {
  const _AccionesRow({required this.usuario, required this.refWidget});
  final UsuarioModel usuario;
  final WidgetRef refWidget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.edit_outlined, size: 18),
          tooltip: 'Editar',
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
          icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
          tooltip: 'Desactivar',
          onPressed: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (dialogCtx) => AlertDialog(
                title: const Text('Desactivar usuario'),
                content: Text('¿Estás seguro de desactivar a ${usuario.username}?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(true),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                    child: const Text('Desactivar'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              try {
                await ref.read(usuariosControllerProvider).eliminar(usuario.id);
                if (context.mounted) context.showSnack('Usuario desactivado');
              } catch (e) {
                if (context.mounted) context.showSnack(e.toString(), isError: true);
              }
            }
          },
        ),
      ],
    );
  }
}
