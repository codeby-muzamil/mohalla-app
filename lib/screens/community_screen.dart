import 'package:flutter/material.dart';

import '../services/data_service.dart';
import '../widgets/common.dart';

/// Community: Elaan (announcements), Islamic News, Madad (mutual aid).
/// All content is SAMPLE and labelled as such — real posts come from
/// the community backend (Firebase) later, see BUILD_NOTES.md.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: SampleBanner(),
        ),
        TabBar(
          controller: _tabs,
          labelColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(text: 'Elaan'),
            Tab(text: 'Islamic News'),
            Tab(text: 'Madad'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _PostList(posts: SampleCommunity.elaan, icon: Icons.campaign),
              _PostList(posts: SampleCommunity.news, icon: Icons.newspaper),
              _PostList(posts: SampleCommunity.madad, icon: Icons.handshake),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: SampleNote(
            text:
                'Community posts, news aur madad campaigns abhi sample hain. '
                'Asal data masjid/community admin se Firebase ke zariye aayega.',
          ),
        ),
      ],
    );
  }
}

class _PostList extends StatelessWidget {
  final List<Map<String, String>> posts;
  final IconData icon;

  const _PostList({required this.posts, required this.icon});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: posts.length,
      itemBuilder: (context, i) {
        final p = posts[i];
        return Card(
          child: ListTile(
            leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
            title: Text(p['title'] ?? ''),
            subtitle: Text(p['body'] ?? ''),
            trailing: Text(
              p['time'] ?? '',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }
}
