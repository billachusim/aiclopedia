import 'package:shared_preferences/shared_preferences.dart';

/// A service to manage a local list of post IDs that the user has hidden.
/// This prevents removed/blocked content from reappearing in the feed.
class HiddenPostsService {
  static const _hiddenPostsKey = 'hidden_post_ids';

  // Get the list of hidden post IDs from local storage.
  Future<List<String>> getHiddenPostIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_hiddenPostsKey) ?? [];
  }

  // Add a post ID to the hidden list.
  Future<void> hidePost(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    // Fetch the current list.
    List<String> hiddenIds = await getHiddenPostIds();
    // Add the new ID if it's not already in the list.
    if (!hiddenIds.contains(postId)) {
      hiddenIds.add(postId);
      await prefs.setStringList(_hiddenPostsKey, hiddenIds);
    }
  }
}
