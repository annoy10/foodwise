import 'package:flutter/material.dart';
import '../services/api.dart';

class RagChatScreen extends StatefulWidget {
  final Api api;
  const RagChatScreen({super.key, required this.api});
  @override
  State<RagChatScreen> createState() => _RagChatScreenState();
}

class _RagChatScreenState extends State<RagChatScreen> {
  final input = TextEditingController();
  final messages = <Map<String, String>>[];
  bool loading = false;
  @override
  void dispose() { input.dispose(); super.dispose(); }

  Future<void> send() async {
    final q = input.text.trim();
    if (q.isEmpty || loading) return;
    setState(() { messages.add({'role':'user','text':q}); loading = true; input.clear(); });
    try {
      final data = await widget.api.askRag(q);
      if (!mounted) return;
      final sources = (data['sources'] as List<dynamic>? ?? []).join(', ');
      setState(() { messages.add({'role':'assistant','text':'${data['reply']}\n\nRetrieved recipes: $sources'}); });
    } catch (e) {
      if (mounted) setState(() => messages.add({'role':'assistant','text':'Chat unavailable: $e'}));
    } finally { if (mounted) setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    Expanded(child: ListView.builder(
      padding: const EdgeInsets.all(14), itemCount: messages.length,
      itemBuilder: (ctx,i) {
        final msg=messages[i]; final mine=msg['role']=='user';
        return Align(alignment:mine?Alignment.centerRight:Alignment.centerLeft,
          child: Container(margin: const EdgeInsets.symmetric(vertical:6), padding: const EdgeInsets.all(14),
            constraints: const BoxConstraints(maxWidth:620),
            decoration:BoxDecoration(color:mine?const Color(0xFFD9F2DD):Colors.white,
              borderRadius:BorderRadius.circular(18)), child:Text(msg['text']??'')));
      },
    )),
    if (loading) const LinearProgressIndicator(),
    Padding(padding: const EdgeInsets.all(12), child: Row(children: [
      Expanded(child: TextField(controller: input,
        onSubmitted: (_) => send(),
        decoration: const InputDecoration(labelText:'What can I cook?',
          hintText:'আমার কাছে ১টা ডিম, ২টা আলু ও টমেটো আছে...'))),
      const SizedBox(width:8), IconButton.filled(onPressed:loading?null:send,
        icon:const Icon(Icons.send)),
    ])),
  ]);
}
