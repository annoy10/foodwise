
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/api.dart';

// ==========================================
// BANGLA TO ENGLISH RECIPE IMAGE SEARCH
// ==========================================

const Map<String, String> englishNames = {
  // Fish recipes
  'ইলিশ মাছের কারি': 'Hilsa fish curry',
  'ইলিশ মাছের ঝোল': 'Hilsa fish curry',
  'ইলিশ মাছ ভাজা': 'Fried hilsa fish',
  'পাবদা মাছের কারি': 'Pabda fish curry',
  'পাপদা মাছের কারি': 'Pabda fish curry',
  'পাবদা মাছের ঝোল': 'Pabda fish curry',
  'রুই মাছের ঝোল': 'Rohu fish curry',
  'রুই মাছের কারি': 'Rohu fish curry',
  'কাতলা মাছের ঝোল': 'Catla fish curry',
  'কাতলা মাছের কারি': 'Catla fish curry',
  'মাছের ভুনা': 'Bengali fish bhuna',
  'মাছ ভাজা': 'Fried fish',

  // Egg recipes
  'টমেটো অমলেট': 'Tomato Omelette',
  'ডিমের অমলেট': 'Omelette',
  'ডিমের ঝোল': 'Egg curry',
  'ডিমের কারি': 'Egg curry',
  'ডিম ভাজি': 'Fried egg',
  'সেদ্ধ ডিমের সালাদ': 'Boiled egg salad',
  'ডিমের সালাদ': 'Egg salad',
  'ডিম খিচুড়ি': 'Egg khichdi',

  // Rice recipes
  'খিচুড়ি': 'Khichdi',
  'সবজি খিচুড়ি': 'Vegetable khichdi',
  'চিকেন বিরিয়ানি': 'Chicken biryani',
  'বিরিয়ানি': 'Biryani',
  'ভেজিটেবল পোলাও': 'Vegetable pulao',
  'পোলাও': 'Pulao',
  'ফ্রাইড রাইস': 'Fried rice',
  'ডিম ভাত': 'Egg rice',

  // Chicken recipes
  'মুরগির ঝোল': 'Chicken curry',
  'মুরগির কারি': 'Chicken curry',
  'চিকেন কারি': 'Chicken curry',
  'চিকেন ভুনা': 'Chicken bhuna',
  'চিকেন স্যুপ': 'Chicken soup',
  'চিকেন ফ্রাই': 'Fried chicken',

  // Vegetable recipes
  'আলু ভর্তা': 'Aloo bhorta',
  'আলু ভাজি': 'Fried potatoes',
  'আলুর দম': 'Dum aloo',
  'মিশ্র সবজি': 'Mixed vegetable curry',
  'সবজি ভাজি': 'Stir fried vegetables',
  'ডাল': 'Lentil dal',
  'মসুর ডাল': 'Masoor dal',

  // Other recipes
  'পাস্তা': 'Pasta',
  'টমেটো পাস্তা': 'Tomato pasta',
  'নুডলস': 'Noodles',
  'সবজি স্যুপ': 'Vegetable soup',
  'স্যান্ডউইচ': 'Sandwich',
  'প্যানকেক': 'Pancake',
};

// ==========================================
// CHAT SCREEN
// ==========================================

class RagChatScreen extends StatefulWidget {
  final Api api;

  const RagChatScreen({
    super.key,
    required this.api,
  });

  @override
  State<RagChatScreen> createState() =>
      _RagChatScreenState();
}

class _RagChatScreenState extends State<RagChatScreen> {
  final input = TextEditingController();
  final scrollController = ScrollController();

  final List<Map<String, dynamic>> messages = [];

  final Map<String, Future<String?>> imageCache = {};

  bool loading = false;

  @override
  void dispose() {
    input.dispose();
    scrollController.dispose();
    super.dispose();
  }

  // ==========================================
  // CONVERT BANGLA NAME TO ENGLISH
  // ==========================================

  String getEnglishRecipeName(String recipeName) {
    final name = recipeName.trim();

    final directMatch = englishNames[name];

    if (directMatch != null) {
      return directMatch;
    }

    // Handle different punctuation or emoji
    // around recipe names.
    for (final entry in englishNames.entries) {
      if (name.contains(entry.key)) {
        return entry.value;
      }
    }

    // English recipe names remain unchanged.
    return name;
  }

  // ==========================================
  // FIND RECIPE IMAGE FROM WIKIMEDIA
  // ==========================================

  Future<String?> findRecipeImage(
      String recipeName,
      ) async {
    final name = recipeName.trim();

    if (name.isEmpty) return null;

    final searchName = getEnglishRecipeName(name);

    debugPrint('Recipe name: $name');
    debugPrint('Image search name: $searchName');

    try {
      final uri = Uri.https(
        'commons.wikimedia.org',
        '/w/api.php',
        {
          'action': 'query',
          'generator': 'search',
          'gsrsearch': searchName,
          'gsrnamespace': '6',
          'gsrlimit': '30',
          'prop': 'imageinfo',
          'iiprop': 'url|mime',
          'iiurlwidth': '800',
          'format': 'json',
          'origin': '*',
        },
      );

      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
      );

      debugPrint(
        'Image API status: ${response.statusCode}',
      );

      if (response.statusCode != 200) {
        debugPrint('Image API request failed');
        return null;
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map) {
        return null;
      }

      final query = decoded['query'];

      if (query is! Map) {
        debugPrint('No image results: $searchName');
        return null;
      }

      final pages = query['pages'];

      if (pages is! Map) {
        debugPrint('No image pages: $searchName');
        return null;
      }

      final words = searchName
          .toLowerCase()
          .split(RegExp(r'\s+'))
          .where((word) => word.length > 2)
          .toList();

      final candidates = <Map<String, dynamic>>[];

      // ======================================
      // CHECK SEARCH RESULTS
      // ======================================

      for (final pageValue in pages.values) {
        if (pageValue is! Map) continue;

        final page = Map<String, dynamic>.from(
          pageValue,
        );

        final imageInfo = page['imageinfo'];

        if (imageInfo is! List || imageInfo.isEmpty) {
          continue;
        }

        final image = imageInfo.first;

        if (image is! Map) continue;

        final mime =
            image['mime']?.toString() ?? '';

        if (mime != 'image/jpeg' &&
            mime != 'image/png' &&
            mime != 'image/webp') {
          continue;
        }

        final title =
            page['title']?.toString() ?? '';

        final url =
            image['thumburl']?.toString() ??
                image['url']?.toString();

        if (url == null ||
            !url.startsWith('https://')) {
          continue;
        }

        final lowerTitle = title.toLowerCase();

        final score = words
            .where(
              (word) => lowerTitle.contains(word),
        )
            .length;

        if (score == 0) continue;

        candidates.add({
          'title': title,
          'url': url,
          'score': score,
        });
      }

      // ======================================
      // SORT IMAGES BY RELEVANCE
      // ======================================

      candidates.sort((a, b) {
        final aScore = a['score'] as int;
        final bScore = b['score'] as int;

        return bScore.compareTo(aScore);
      });

      if (candidates.isEmpty) {
        debugPrint(
          'No matching food photo: $searchName',
        );

        return null;
      }

      final best = candidates.first;

      final bestScore = best['score'] as int;

      // For multi-word names, require at least
      // two matching search words.
      if (words.length >= 2 && bestScore < 2) {
        debugPrint(
          'Image match too weak: $searchName',
        );

        return null;
      }

      final imageUrl = best['url'] as String;

      debugPrint(
        'Image found: $imageUrl',
      );

      return imageUrl;
    } catch (e) {
      debugPrint(
        'Recipe image error: $e',
      );

      return null;
    }
  }

  // ==========================================
  // IMAGE CACHE
  // ==========================================

  Future<String?> getRecipeImage(
      String recipeName,
      ) {
    return imageCache.putIfAbsent(
      recipeName,
          () => findRecipeImage(recipeName),
    );
  }

  // ==========================================
  // EXTRACT RECIPE NAMES FROM AI REPLY
  // ==========================================

  List<String> extractRecipeNames(
      String reply,
      List<String> sources,
      ) {
    final names = <String>[];

    final headingPattern = RegExp(
      r'রেসিপির নাম\s*:\s*([^\r\n]+)',
    );

    for (final match
    in headingPattern.allMatches(reply)) {
      final name = match.group(1)?.trim();

      if (name != null &&
          name.isNotEmpty &&
          !names.contains(name)) {
        names.add(name);
      }
    }

    if (names.isEmpty && sources.isNotEmpty) {
      names.addAll(sources.take(2));
    }

    return names.take(2).toList();
  }

  // ==========================================
  // SEND USER MESSAGE
  // ==========================================

  Future<void> send() async {
    final question = input.text.trim();

    if (question.isEmpty || loading) return;

    setState(() {
      messages.add({
        'role': 'user',
        'text': question,
      });

      loading = true;
      input.clear();
    });

    _scrollToBottom();

    try {
      final data = await widget.api.askRag(
        question,
      );

      if (!mounted) return;

      final reply =
          data['reply']?.toString() ?? '';

      final sources =
      (data['sources'] as List? ?? [])
          .map(
            (value) => value.toString(),
      )
          .where(
            (name) => name.trim().isNotEmpty,
      )
          .toList();

      final recipeNames = extractRecipeNames(
        reply,
        sources,
      );

      // Prefer actual recipe names extracted
      // from the Bengali answer.
      // Fall back to English source titles
      // only when headings are unavailable.
      final searchNames = recipeNames;

      setState(() {
        messages.add({
          'role': 'assistant',
          'text': reply,
          'recipes': searchNames,
        });
      });

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        messages.add({
          'role': 'assistant',
          'text': 'Chat unavailable: $e',
          'recipes': <String>[],
        });
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  // ==========================================
  // AUTO SCROLL
  // ==========================================

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback(
          (_) {
        if (!scrollController.hasClients) {
          return;
        }

        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(
            milliseconds: 250,
          ),
          curve: Curves.easeOut,
        );
      },
    );
  }

  // ==========================================
  // RECIPE IMAGE WIDGET
  // ==========================================

  Widget recipeImage(String recipeName) {
    return FutureBuilder<String?>(
      future: getRecipeImage(recipeName),
      builder: (context, snapshot) {
        if (snapshot.connectionState !=
            ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(
              vertical: 16,
            ),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final imageUrl = snapshot.data;

        if (imageUrl == null) {
          return Padding(
            padding: const EdgeInsets.only(
              bottom: 12,
            ),
            child: Text(
              '$recipeName: ছবি পাওয়া যায়নি',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(
            bottom: 12,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Image.network(
                  imageUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (
                      context,
                      error,
                      stackTrace,
                      ) {
                    debugPrint(
                      'Image loading error: $error',
                    );

                    return const SizedBox(
                      height: 80,
                      child: Center(
                        child: Text(
                          'ছবি লোড করা যায়নি',
                        ),
                      ),
                    );
                  },
                ),

                Padding(
                  padding: const EdgeInsets.all(
                    8,
                  ),
                  child: Text(
                    recipeName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // MESSAGE BUBBLE
  // ==========================================

  Widget messageBubble(
      Map<String, dynamic> msg,
      ) {
    final mine = msg['role'] == 'user';

    final text =
        msg['text']?.toString() ?? '';

    final recipes =
        (msg['recipes'] as List?)?.cast<String>() ??
            <String>[];

    return Align(
      alignment: mine
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(
          vertical: 6,
        ),
        padding: const EdgeInsets.all(14),
        constraints: const BoxConstraints(
          maxWidth: 620,
        ),
        decoration: BoxDecoration(
          color: mine
              ? const Color(0xFFD9F2DD)
              : Colors.white,
          borderRadius: BorderRadius.circular(
            18,
          ),
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            if (!mine)
              for (final recipe in recipes)
                recipeImage(recipe),

            SelectableText(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // CHAT SCREEN UI
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: const EdgeInsets.all(
              14,
            ),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              return messageBubble(
                messages[index],
              );
            },
          ),
        ),

        if (loading)
          const LinearProgressIndicator(),

        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: input,
                  textInputAction:
                  TextInputAction.send,
                  onSubmitted: (_) => send(),
                  decoration:
                  const InputDecoration(
                    labelText:
                    'What can I cook?',
                    hintText:
                    'আমার কাছে ডিম, আলু ও টমেটো আছে...',
                  ),
                ),
              ),

              const SizedBox(width: 8),

              IconButton.filled(
                onPressed:
                loading ? null : send,
                icon: const Icon(
                  Icons.send,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
