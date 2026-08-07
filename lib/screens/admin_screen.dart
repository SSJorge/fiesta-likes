import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/party_user.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  int _selectedIndex = 0;

  static const List<String> _titles = ['Ranking', 'Historial', 'Cuentas'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Panel de administrador · ${_titles[_selectedIndex]}'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildRankingView(),
          _buildHistoryView(),
          _buildAccountsView(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Ranking',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Cuentas',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 2
          ? FloatingActionButton.extended(
              onPressed: _showCreateParticipantDialog,
              icon: const Icon(Icons.person_add),
              label: const Text('Crear cuenta'),
            )
          : null,
    );
  }

  // ============================================================
  // RANKING
  // ============================================================

  Widget _buildRankingView() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('profiles').orderBy('createdAt').snapshots(),
      builder: (context, profilesSnapshot) {
        if (profilesSnapshot.hasError) {
          return _ErrorView(
            message: _firestoreErrorMessage(profilesSnapshot.error),
          );
        }

        if (!profilesSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = profilesSnapshot.data!.docs
            .map(PartyUser.fromFirestore)
            .toList();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _db.collection('likes').snapshots(),
          builder: (context, likesSnapshot) {
            if (likesSnapshot.hasError) {
              return _ErrorView(
                message: _firestoreErrorMessage(likesSnapshot.error),
              );
            }

            if (!likesSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final likeCounts = <String, int>{};

            for (final likeDocument in likesSnapshot.data!.docs) {
              final data = likeDocument.data();
              final targetUid = data['targetUid'];

              if (targetUid is! String) {
                continue;
              }

              likeCounts[targetUid] = (likeCounts[targetUid] ?? 0) + 1;
            }

            final ranking =
                users
                    .map(
                      (user) => RankingEntry(
                        user: user,
                        likes: likeCounts[user.uid] ?? 0,
                      ),
                    )
                    .toList()
                  ..sort((first, second) {
                    final likesComparison = second.likes.compareTo(first.likes);

                    if (likesComparison != 0) {
                      return likesComparison;
                    }

                    return _compareCreationOrder(first.user, second.user);
                  });

            if (ranking.isEmpty) {
              return const _EmptyView(
                icon: Icons.emoji_events_outlined,
                title: 'No hay participantes',
                message: 'Crea cuentas para comenzar a mostrar el ranking.',
              );
            }

            final totalLikes = likesSnapshot.data!.docs.length;

            return Column(
              children: [
                _RankingSummary(
                  participantCount: users.length,
                  totalLikes: totalLikes,
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: ranking.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = ranking[index];

                      return _RankingTile(
                        position: index + 1,
                        name: entry.user.displayName,
                        likes: entry.likes,
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // HISTORIAL
  // ============================================================

  Widget _buildHistoryView() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('profiles').snapshots(),
      builder: (context, profilesSnapshot) {
        if (profilesSnapshot.hasError) {
          return _ErrorView(
            message: _firestoreErrorMessage(profilesSnapshot.error),
          );
        }

        if (!profilesSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final namesByUid = <String, String>{};

        for (final document in profilesSnapshot.data!.docs) {
          final data = document.data();

          namesByUid[document.id] =
              data['displayName'] as String? ?? 'Usuario desconocido';
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _db
              .collection('likeEvents')
              .orderBy('createdAt', descending: true)
              .limit(500)
              .snapshots(),
          builder: (context, eventsSnapshot) {
            if (eventsSnapshot.hasError) {
              return _ErrorView(
                message: _firestoreErrorMessage(eventsSnapshot.error),
              );
            }

            if (!eventsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final events = eventsSnapshot.data!.docs;

            if (events.isEmpty) {
              return const _EmptyView(
                icon: Icons.history,
                title: 'No hay actividad',
                message: 'Aquí aparecerán los likes agregados y retirados.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: events.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final event = events[index].data();

                final fromUid = event['fromUid'] as String?;
                final targetUid = event['targetUid'] as String?;
                final action = event['action'] as String?;
                final createdAt = event['createdAt'] as Timestamp?;

                final fromName =
                    namesByUid[fromUid] ?? 'Usuario eliminado o desconocido';

                final targetName =
                    namesByUid[targetUid] ?? 'Usuario eliminado o desconocido';

                final isLike = action == 'like';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isLike
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      isLike ? Icons.favorite : Icons.heart_broken_outlined,
                      color: isLike
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  title: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: fromName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: isLike ? ' dio like a ' : ' quitó su like a ',
                        ),
                        TextSpan(
                          text: targetName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  subtitle: Text(_formatTimestamp(createdAt)),
                );
              },
            );
          },
        );
      },
    );
  }

  // ============================================================
  // CUENTAS
  // ============================================================

  Widget _buildAccountsView() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('profiles').orderBy('createdAt').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorView(message: _firestoreErrorMessage(snapshot.error));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final users = snapshot.data!.docs.map(PartyUser.fromFirestore).toList();

        if (users.isEmpty) {
          return const _EmptyView(
            icon: Icons.people_outline,
            title: 'No hay cuentas',
            message:
                'Presiona “Crear cuenta” para agregar al primer participante.',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: users.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final user = users[index];

            return ListTile(
              leading: CircleAvatar(child: Text('${index + 1}')),
              title: Text(
                user.displayName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text('Creada: ${_formatTimestamp(user.createdAt)}'),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // CREAR PARTICIPANTE
  // ============================================================

  Future<void> _showCreateParticipantDialog() async {
    final nameController = TextEditingController();
    final passwordController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    bool obscurePassword = true;
    bool loading = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> createParticipant() async {
              if (loading) {
                return;
              }

              if (!(formKey.currentState?.validate() ?? false)) {
                return;
              }

              setDialogState(() {
                loading = true;
                errorMessage = null;
              });

              try {
                final callable = _functions.httpsCallable('createParticipant');

                await callable.call(<String, dynamic>{
                  'displayName': nameController.text.trim(),
                  'password': passwordController.text,
                });

                if (!dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();

                _showMessage('Cuenta creada correctamente.');
              } on FirebaseFunctionsException catch (error) {
                setDialogState(() {
                  loading = false;
                  errorMessage = _functionErrorMessage(error);
                });
              } catch (error) {
                setDialogState(() {
                  loading = false;
                  errorMessage = 'No se pudo crear la cuenta: $error';
                });
              }
            }

            return AlertDialog(
              title: const Text('Crear participante'),
              content: SizedBox(
                width: 420,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        autofocus: true,
                        enabled: !loading,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          hintText: 'Ejemplo: Camila',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final name = value?.trim() ?? '';

                          if (name.isEmpty) {
                            return 'Ingresa un nombre.';
                          }

                          if (name.length < 2) {
                            return 'El nombre es demasiado corto.';
                          }

                          if (name.length > 40) {
                            return 'El nombre no puede superar 40 caracteres.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: passwordController,
                        enabled: !loading,
                        obscureText: obscurePassword,
                        onFieldSubmitted: (_) {
                          createParticipant();
                        },
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          helperText: 'Mínimo 6 caracteres',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: obscurePassword
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            onPressed: loading
                                ? null
                                : () {
                                    setDialogState(() {
                                      obscurePassword = !obscurePassword;
                                    });
                                  },
                            icon: Icon(
                              obscurePassword
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final password = value ?? '';

                          if (password.isEmpty) {
                            return 'Ingresa una contraseña.';
                          }

                          if (password.length < 6) {
                            return 'Debe tener al menos 6 caracteres.';
                          }

                          return null;
                        },
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            errorMessage!,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: loading
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: loading ? null : createParticipant,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add),
                  label: Text(loading ? 'Creando...' : 'Crear cuenta'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    passwordController.dispose();
  }

  // ============================================================
  // FUNCIONES AUXILIARES
  // ============================================================

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cerrar sesión'),
          content: const Text('¿Quieres salir del panel de administrador?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await FirebaseAuth.instance.signOut();
  }

  int _compareCreationOrder(PartyUser first, PartyUser second) {
    final firstTimestamp = first.createdAt;
    final secondTimestamp = second.createdAt;

    if (firstTimestamp == null && secondTimestamp == null) {
      return first.displayName.compareTo(second.displayName);
    }

    if (firstTimestamp == null) {
      return 1;
    }

    if (secondTimestamp == null) {
      return -1;
    }

    return firstTimestamp.compareTo(secondTimestamp);
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Fecha pendiente';
    }

    final date = timestamp.toDate().toLocal();

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year · $hour:$minute';
  }

  String _functionErrorMessage(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'already-exists':
        return 'Ya existe una cuenta con ese nombre.';

      case 'invalid-argument':
        return error.message ?? 'Los datos ingresados no son válidos.';

      case 'permission-denied':
        return 'Tu cuenta no tiene permisos de administrador.';

      case 'unauthenticated':
        return 'La sesión expiró. Vuelve a ingresar.';

      case 'unavailable':
        return 'El servicio no está disponible en este momento.';

      case 'not-found':
        return 'No se encontró la función createParticipant. '
            'Debes desplegar las Cloud Functions.';

      default:
        return error.message ?? 'Ocurrió un error al crear la cuenta.';
    }
  }

  String _firestoreErrorMessage(Object? error) {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'No tienes permiso para acceder a estos datos. '
            'Revisa el documento admins y las reglas de Firestore.';
      }

      if (error.code == 'failed-precondition') {
        return 'Firestore necesita un índice para ejecutar esta consulta.';
      }

      return error.message ?? 'Error de Firestore: ${error.code}';
    }

    return 'Ocurrió un error al cargar la información.';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

// ============================================================
// MODELOS INTERNOS DE LA PANTALLA
// ============================================================

class RankingEntry {
  final PartyUser user;
  final int likes;

  const RankingEntry({required this.user, required this.likes});
}

// ============================================================
// WIDGETS AUXILIARES
// ============================================================

class _RankingSummary extends StatelessWidget {
  final int participantCount;
  final int totalLikes;

  const _RankingSummary({
    required this.participantCount,
    required this.totalLikes,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              icon: Icons.people,
              label: 'Participantes',
              value: participantCount.toString(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryCard(
              icon: Icons.favorite,
              label: 'Likes actuales',
              value: totalLikes.toString(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  final int position;
  final String name;
  final int likes;

  const _RankingTile({
    required this.position,
    required this.name,
    required this.likes,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        minTileHeight: 72,
        leading: _RankingPosition(position: position),
        title: Text(
          name,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite,
                size: 18,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 6),
              Text(
                likes.toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RankingPosition extends StatelessWidget {
  final int position;

  const _RankingPosition({required this.position});

  @override
  Widget build(BuildContext context) {
    final IconData? medalIcon = switch (position) {
      1 => Icons.workspace_premium,
      2 => Icons.military_tech,
      3 => Icons.military_tech,
      _ => null,
    };

    if (medalIcon != null) {
      return CircleAvatar(child: Icon(medalIcon));
    }

    return CircleAvatar(
      child: Text(
        position.toString(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyView({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;

  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'No se pudo cargar la información',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
