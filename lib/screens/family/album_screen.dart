import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/child_quest.dart';
import '../../services/app_services.dart';
import '../../state/session_controller.dart';
import '../../widgets/notebook.dart';

/// Семейный Альбом Побед — фото «После» принятых квестов.
class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  late final Stream<List<VictoryPhoto>> _stream = context.read<AppServices>().quests.watchAlbum(
    context.read<SessionController>().household!.id,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🏆 Альбом Побед')),
      body: NotebookPaper(
        child: StreamBuilder<List<VictoryPhoto>>(
          stream: _stream,
          builder: (context, snap) {
            final photos = snap.data ?? const [];
            if (photos.isEmpty) {
              return const Center(
                child: Text(
                  'Здесь появятся фото побед над монстриками',
                  style: TextStyle(color: Pen.pencil),
                ),
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: photos.length,
              itemBuilder: (_, i) {
                final p = photos[i];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Image.network(
                          p.photoUrl,
                          // На вебе — через <img>: фото из Storage без настройки CORS бакета.
                          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Center(child: Text('📷')),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          '${p.childName}: ${p.questTitle}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Pen.blue),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
