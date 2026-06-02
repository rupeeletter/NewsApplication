import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:news_application/screens/home_screen.dart';
import 'chatbot_screen.dart';
import '../models/article.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'events_screen.dart';
import 'profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'index_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';


class SavedNewsFeedScreen extends StatefulWidget {
  final String? openFileName;

  const SavedNewsFeedScreen({super.key, this.openFileName});


  @override
  State<SavedNewsFeedScreen> createState() => _SavedNewsFeedScreenState();
}

class _SavedNewsFeedScreenState extends State<SavedNewsFeedScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Article> _articles = [];
  List<Article> _filtered = [];
  List<CorporateEvent> _savedEvents = [];
  List<CorporateEvent> _filteredEvents = [];

  bool _isLoading = false;
  String _error = '';
  int _bottomIndex = 4;
  int _tabIndex = 0;
  late String currentUserId;
  Set<String> _viewedArticles = {};
  String? _expandedItemId; // Track expanded card (for both news and events)
  // InterstitialAd? _interstitialAd;
  // bool _isShowingAd = false;

  Future<List<Map<String, dynamic>>> _fetchCompanyDetails(
    List<String> companyNames) async {
  final names = companyNames.join(",");
  final url = "$baseUrl/api/company-lookup/by-names?names=$names";
  final resp = await http.get(Uri.parse(url));
  if (resp.statusCode != 200) throw Exception("Failed to fetch company details");
  final body = jsonDecode(resp.body);
  return List<Map<String, dynamic>>.from(body["data"]);
}

Future<void> _openTradingView(String symbol) async {
  final url = "https://www.tradingview.com/chart/?symbol=NSE:$symbol";
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    await launchUrl(uri, mode: LaunchMode.inAppWebView);
  }
}

void _showCompanySelector(List<Map<String, dynamic>> companies) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "View chart on TradingView",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        ...companies.map(
          (c) => ListTile(
            title: Text(c["name"]),
            subtitle: Text("NSE:${c["symbol"]}"),
            onTap: () {
              Navigator.pop(context);
              _openTradingView(c["symbol"]);
            },
          ),
        ),
      ],
    ),
  );
}



  //final String baseUrl = "http://10.244.218.93:5000";
  final String baseUrl = "http://51.20.136.45:5000";

 @override
void initState() {
  super.initState();
  _searchController.addListener(_applySearch);
  // _loadInterstitialAd();

  _loadUserId().then((_) {
    if (currentUserId.isNotEmpty) {
      _fetchSavedNews();
    }
  });
}

// void _loadInterstitialAd() {
//   InterstitialAd.load(
//     adUnitId: 'ca-app-pub-6088749573646337/6577319196',
//     request: const AdRequest(),
//     adLoadCallback: InterstitialAdLoadCallback(
//       onAdLoaded: (ad) {
//         _interstitialAd = ad;
//       },
//       onAdFailedToLoad: (error) {
//         debugPrint("Interstitial ad load failed: $error");
//       },
//     ),
//   );
// }



  @override
  void dispose() {
    _searchController.removeListener(_applySearch);
    _searchController.dispose();
    // _interstitialAd?.dispose();
    super.dispose();
  }

Future<void> _loadUserId() async {
  final prefs = await SharedPreferences.getInstance();
  currentUserId = prefs.getString("userId") ?? "";
}

  // ------------------------- SEARCH -------------------------
 void _applySearch() {
  final q = _searchController.text.trim().toLowerCase();

  if (_tabIndex == 0) {
    if (q.isEmpty) {
      setState(() => _filtered = List.from(_articles));
      return;
    }

    setState(() {
      _filtered = _articles.where((a) {
        return '${a.title} ${a.summary}'.toLowerCase().contains(q);
      }).toList();
    });
  } else {
    if (q.isEmpty) {
      setState(() => _filteredEvents = List.from(_savedEvents));
      return;
    }

    setState(() {
      _filteredEvents = _savedEvents.where((e) {
        return '${e.title} ${e.description}'.toLowerCase().contains(q);
      }).toList();
    });
  }
}



 Future<void> _fetchSavedNews() async {
  setState(() {
    _isLoading = true;
    _error = "";
  });

  try {
    final resp = await http.get(
      Uri.parse("$baseUrl/api/users/$currentUserId/saved-news"),
    );

    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      final List data = body['data'];

     _articles = data.map((e) {
  return Article(
    id: (e["newsId"] is Map && e["newsId"]["_id"] != null)
        ? e["newsId"]["_id"].toString()
        : (e["newsId"] ?? "").toString(),

    title: e["headline"] ?? "",
    summary: e["summary"] ?? "",
    story: e["story"] ?? "",

    fileName: "",
    excerpt: e["summary"] ?? "",

    tags: [],

    url: "",

    companies: List<String>.from(e["companys"] ?? []),
    commodities_market:
        List<String>.from(e["commodities_market"] ?? []),
    sector_market:
        e["sector_market"] ?? "",

    date: e["savedAt"] != null
        ? DateTime.parse(e["savedAt"])
        : DateTime.now(),

    sentiment: e["sentiment"] ?? "",
    impact: e["impact"] ?? "",
  );
}).where((a) => a.title.trim().isNotEmpty || a.summary.trim().isNotEmpty)
  .toList();

      _filtered = List.from(_articles);
    } else {
      _error = "Failed to load saved news";
    }
  } catch (e) {
    _error = "Error: $e";
  }

  setState(() => _isLoading = false);
}

 // ------------------------- SHOW FULL STORY -------------------------
 Future<void> _showFullStory(Article a) async {
  Color sentimentColor(String s) {
    switch (s.toLowerCase()) {
      case "bullish":
        return Colors.green;
      case "bearish":
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Color impactColor(String i) {
    switch (i.toLowerCase()) {
      case "very high":
        return Colors.red;
      case "high":
        return Colors.orange;
      case "medium":
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor:Color.fromARGB(255, 245, 237, 237),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// TITLE
            Text(
              a.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            /// FULL STORY
              if (a.story.isNotEmpty) ...[
                const Text(
                  "Full Story",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),

                Html(
                  data: a.story, // 👈 COMPLETE NEWS CONTENT
                  style: {
                    "p": Style(
                      fontSize: FontSize(14.5),
                      lineHeight: LineHeight.number(1.5),
                      margin: Margins.only(bottom: 12),
                    ),
                  },
                ),

                const SizedBox(height: 16),
              ],


            /// SENTIMENT + IMPACT (same as card)
            
                if (a.sentiment.isNotEmpty)
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: "Sentiment: ",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                          text: a.sentiment,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: sentimentColor(a.sentiment),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 12),
                if (a.impact.isNotEmpty)
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: "Impact: ",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(
                          text: a.impact,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: impactColor(a.impact),
                          ),
                        ),
                      ],
                    ),
                  ),
             

            /// COMPANIES
            if (a.companies.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                "Companies",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: a.companies.map(
                  (company) => Chip(
                    label: Text(
                      company,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                    backgroundColor: const Color(0xFFEA6B6B),
                  ),
                ).toList(),
              ),
            ],

            const SizedBox(height: 20),

            /// CLOSE BUTTON
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  "Close",
                  style: TextStyle(
                    color: Color(0xFFEA6B6B),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


Future<void> _fetchSavedEvents() async {
  setState(() {
    _isLoading = true;
    _error = "";
  });

  try {
    final resp = await http.get(
      Uri.parse("$baseUrl/api/users/$currentUserId/saved-events"),
    );

    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      final List data = body['data'];

      _savedEvents =
          data.map((e) => CorporateEvent.fromJson(e)).toList();

      _filteredEvents = List.from(_savedEvents);
    } else {
      _error = "Failed to load saved events";
    }
  } catch (e) {
    _error = "Error: $e";
  }

  setState(() => _isLoading = false);
}
Future<void> _removeAllSavedNews() async {
  final resp = await http.delete(
    Uri.parse("$baseUrl/api/users/$currentUserId/saved-news"),
  );

  if (resp.statusCode == 200) {
    setState(() {
      _articles.clear();
      _filtered.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("All saved news removed")),
    );
  }
}
Future<void> _removeAllSavedEvents() async {
  final resp = await http.delete(
    Uri.parse("$baseUrl/api/users/$currentUserId/saved-events"),
  );

  if (resp.statusCode == 200) {
    setState(() {
      _savedEvents.clear();
      _filteredEvents.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("All saved events removed")),
    );
  }
}
Future<void> _unsaveNews(String newsId) async {
  final article = _articles.firstWhere(
  (a) => a.id == newsId,
  orElse: () => _articles.first,
);

  await http.post(
    Uri.parse("$baseUrl/api/users/save-news"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "userId": currentUserId,
      "newsId": article.id,
      "headline": article.title,
      "summary": article.summary,
      "story": article.story,
      "companys": article.companies,
      "commodities_market": article.commodities_market,
      "sector_market": article.sector_market,
      "sentiment": article.sentiment,
      "impact": article.impact,
    }),
  );

  setState(() {
    _articles.removeWhere((n) => n.id == newsId);
    _filtered.removeWhere((n) => n.id == newsId);
  });
}
Future<void> _unsaveEvent(String eventId) async {
  await http.post(
    Uri.parse("$baseUrl/api/users/save-event"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "userId": currentUserId,
      "eventId": eventId,
    }),
  );

  setState(() {
    _savedEvents.removeWhere((e) => e.id == eventId);
    _filteredEvents.removeWhere((e) => e.id == eventId);
  });
}



  // ------------------------- UI -------------------------
  Widget _buildTopSearchRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF6B3B3),
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: "Search here...",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const Icon(Icons.search),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: CircleAvatar(
  radius: 18,
  backgroundColor: Color(0xFFE0E0E0),
  child: Icon(
    Icons.person,
    size: 18,
    color: Color(0xFF757575),
  ),
),
          ),
        ],
      ),
    );
  }

 Widget _buildTabsRow() {
  final tabs = ["NEWS", "EVENTS"];

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, idx) {
          final selected = idx == _tabIndex;

          return GestureDetector(
            onTap: () {
              setState(() => _tabIndex = idx);

              if (idx == 0) {
                _fetchSavedNews();
              } else {
                _fetchSavedEvents();
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFEDECF0)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                tabs[idx],
                style: TextStyle(
                  fontWeight:
                      selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? Colors.black : Colors.black54,
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
Widget _buildRemoveAllButton() {
  if (_tabIndex == 0 && _articles.isEmpty) return const SizedBox();
  if (_tabIndex == 1 && _savedEvents.isEmpty) return const SizedBox();

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        label: Text(
          _tabIndex == 0
              ? "Remove all saved news"
              : "Remove all saved events",
          style: const TextStyle(color: Colors.red),
        ),
        onPressed: _tabIndex == 0
            ? _removeAllSavedNews
            : _removeAllSavedEvents,
      ),
    ),
  );
}


 Widget _buildFeed() {
  if (_isLoading) {
    return const Expanded(
      child: Center(child: CircularProgressIndicator()),
    );
  }

  if (_error.isNotEmpty) {
    return Expanded(child: Center(child: Text(_error)));
  }

  // 📰 SAVED NEWS
  if (_tabIndex == 0) {
    if (_filtered.isEmpty) {
      return const Expanded(child: Center(child: Text("No saved news")));
    }

    return Expanded(
  child: PageView.builder(
    scrollDirection: Axis.vertical,
    controller: PageController(viewportFraction: 0.72), // keep this
    padEnds: false,
    physics: const BouncingScrollPhysics(),
    itemCount: _filtered.length,
    itemBuilder: (context, index) {
      final article = _filtered[index];

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: VisibilityDetector(
          key: Key(article.id),
          onVisibilityChanged: (info) {
            if (info.visibleFraction > 0.6 &&
    !_viewedArticles.contains(article.id)) {

  _viewedArticles.add(article.id);
  // call analytics API
}
          },
          child: _buildArticleCard(article),
        ),
      );
    },
  ),
);}

  // 📅 SAVED EVENTS
  if (_filteredEvents.isEmpty) {
    return const Expanded(child: Center(child: Text("No saved events")));
  }

  return Expanded(
    child: ListView.builder(
      itemCount: _filteredEvents.length,
      itemBuilder: (_, i) => _buildSavedEventCard(_filteredEvents[i]),
    ),
  );
}
Widget _buildSavedEventCard(CorporateEvent event) {
  final dateFormatted = DateFormat('dd MMM yyyy').format(event.date);
  final timeFormatted = DateFormat('hh:mm a').format(event.date);
  final isExpanded = _expandedItemId == event.id;

  return GestureDetector(
    onTap: () {
      setState(() {
        if (_expandedItemId == event.id) {
          _expandedItemId = null;
        } else {
          _expandedItemId = event.id;
        }
      });
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: const BoxDecoration(
                color: Color(0xFFE54350),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: GoogleFonts.dmSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              height: 32 / 20,
                              color: const Color(0xFF333333),
                            ),
                          ),
                        ),
                        if (isExpanded) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _unsaveEvent(event.id),
                            child: const Icon(
                              Icons.bookmark,
                              color: Color(0xFFE54350),
                              size: 24,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event.description,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 24 / 14,
                        color: const Color(0xFF555555),
                      ),
                      textAlign: TextAlign.justify,
                      maxLines: isExpanded ? null : 2,
                      overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    if (!isExpanded)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              dateFormatted,
                              style: GoogleFonts.dmSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFE54350),
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF94A3B8),
                            size: 24,
                          ),
                        ],
                      ),
                    if (isExpanded) ...[
                      const SizedBox(height: 8),
                      Container(
                        height: 1,
                        color: const Color(0xFFE2E8F0),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time_outlined,
                            size: 16,
                            color: Color(0xFFE54350),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeFormatted,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: Color(0xFFE54350),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dateFormatted,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildArticleCard(Article a) {
  final dateFormatted = DateFormat.yMMMd().add_jm().format(a.date);

  return SizedBox(
    height: MediaQuery.of(context).size.height * 0.75,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showFullStory(a),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              a.title,
              style: GoogleFonts.dmSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  a.summary,
                  textAlign: TextAlign.justify,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 22.75 / 14,
                    color: const Color(0xFF555555),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (a.companies.isNotEmpty)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "Companies: ",
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 20 / 14,
                        color: const Color(0xFF555555),
                      ),
                    ),
                    TextSpan(
                      text: a.companies.join(', '),
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 20 / 14,
                        color: const Color(0xFF555555),
                      ),
                    ),
                  ],
                ),
              )
            else if (a.sector_market.isNotEmpty)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "Sector: ",
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 20 / 14,
                        color: const Color(0xFF555555),
                      ),
                    ),
                    TextSpan(
                      text: a.sector_market,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 20 / 14,
                        color: const Color(0xFF555555),
                      ),
                    ),
                  ],
                ),
              )
            else if (a.commodities_market.isNotEmpty)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "Commodity: ",
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 20 / 14,
                        color: const Color(0xFF555555),
                      ),
                    ),
                    TextSpan(
                      text: a.commodities_market.join(', '),
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 20 / 14,
                        color: const Color(0xFF555555),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            if (a.sentiment.isNotEmpty)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "Sentiment: ",
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 20 / 14,
                        letterSpacing: 0,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    TextSpan(
                      text: a.sentiment,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 20 / 14,
                        color: _getSentimentColor(a.sentiment),
                      ),
                    ),
                  ],
                ),
              ),
            if (a.sentiment.isNotEmpty && a.impact.isNotEmpty)
              const SizedBox(height: 6),
            if (a.impact.isNotEmpty)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "Impact: ",
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 20 / 14,
                        letterSpacing: 0,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    TextSpan(
                      text: a.impact,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 20 / 14,
                        color: _getImpactColor(a.impact),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateFormatted,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF8A8A8A),
                  ),
                ),
                Row(
                  children: [
                    if (a.companies.isNotEmpty)
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Image.asset(
                          "assets/tradingview.png",
                          height: 28,
                          width: 28,
                        ),
                        onPressed: () async {
                          final companies =
                              await _fetchCompanyDetails(a.companies);

                          if (companies.isEmpty) return;

                          if (companies.length == 1) {
                            _openTradingView(companies.first["symbol"]);
                          } else {
                            _showCompanySelector(companies);
                          }
                        },
                      ),
                    const SizedBox(width: 6),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(
                        Icons.bookmark,
                        size: 28,
                        color: Color(0xFFE54350),
                      ),
                      onPressed: () => _unsaveNews(a.id),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Color _getSentimentColor(String s) {
  switch (s.toLowerCase()) {
    case "very bullish":
      return const Color(0xFF0F9D58);
    case "bullish":
      return const Color(0xFF5AD079);
    case "neutral":
      return const Color(0xFFA6A49A);
    case "bearish":
      return const Color(0xFFEB6969);
    case "very bearish":
      return const Color(0xFFD93025);
    default:
      return const Color(0xFF555555);
  }
}

Color _getImpactColor(String i) {
  switch (i.toLowerCase()) {
    case "very high":
      return const Color(0xFFFFB000);
    case "high":
      return const Color(0xFFFF9B5B);
    case "mild":
      return const Color(0xFFFFCD79);
    case "negligible":
      return const Color(0xFFFFCEAF);
    default:
      return const Color(0xFF555555);
  }
}

Color _getSentimentBg(String s) {
  switch (s.toLowerCase()) {
    case "very bullish":
      return const Color(0xFFE8F5E9);
    case "bullish":
      return const Color(0xFFE8F5E9);
    case "neutral":
      return const Color(0xFFF5F5F5);
    case "bearish":
      return const Color(0xFFFFEBEE);
    case "very bearish":
      return const Color(0xFFFFEBEE);
    default:
      return const Color(0xFFF5F5F5);
  }
}

Color _getSentimentBorder(String s) {
  switch (s.toLowerCase()) {
    case "very bullish":
      return const Color(0xFF66BB6A);
    case "bullish":
      return const Color(0xFF81C784);
    case "neutral":
      return const Color(0xFFBDBDBD);
    case "bearish":
      return const Color(0xFFEF5350);
    case "very bearish":
      return const Color(0xFFE53935);
    default:
      return const Color(0xFFBDBDBD);
  }
}

Color _getDarkerSentiment(String s) {
  switch (s.toLowerCase()) {
    case "very bullish":
      return const Color(0xFF2E7D32);
    case "bullish":
      return const Color(0xFF388E3C);
    case "neutral":
      return const Color(0xFF616161);
    case "bearish":
      return const Color(0xFFC62828);
    case "very bearish":
      return const Color(0xFFB71C1C);
    default:
      return Colors.grey;
  }
}

Color _getImpactBg(String i) {
  switch (i.toLowerCase()) {
    case "very high":
      return const Color(0xFFFFF3E0);
    case "high":
      return const Color(0xFFFFF3E0);
    case "mild":
      return const Color(0xFFFFFBF0);
    case "negligible":
      return const Color(0xFFFFFBF0);
    default:
      return const Color(0xFFF5F5F5);
  }
}

Color _getImpactBorder(String i) {
  switch (i.toLowerCase()) {
    case "very high":
      return const Color(0xFFFF9800);
    case "high":
      return const Color(0xFFFFB74D);
    case "mild":
      return const Color(0xFFFFD54F);
    case "negligible":
      return const Color(0xFFFFE082);
    default:
      return const Color(0xFFBDBDBD);
  }
}

Color _getDarkerImpact(String i) {
  switch (i.toLowerCase()) {
    case "very high":
      return const Color(0xFFE65100);
    case "high":
      return const Color(0xFFF57C00);
    case "mild":
      return const Color(0xFFFFA000);
    case "negligible":
      return const Color(0xFFFFB300);
    default:
      return Colors.grey;
  }
}

IconData _getSentimentIcon(String s) {
  switch (s.toLowerCase()) {
    case "very bullish":
    case "bullish":
      return Icons.trending_up;
    case "neutral":
      return Icons.trending_flat;
    case "bearish":
    case "very bearish":
      return Icons.trending_down;
    default:
      return Icons.circle;
  }
}

  BottomNavigationBarItem _navItem({
  required String label,
  required String active,
  required String inactive,
  required int index,
}) {
  final bool selected = _bottomIndex == index;

  return BottomNavigationBarItem(
    icon: SvgPicture.asset(
      selected ? active : inactive,
      height: 22,
    ),
    label: label,
    tooltip: label,
  );
}

  // ------------------------- BUILD -------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopSearchRow(),
            _buildTabsRow(),
            _buildRemoveAllButton(), // 👈 ADD HERE
            const SizedBox(height: 10),
            _buildFeed(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
  decoration: const BoxDecoration(
    color: Colors.white,
    border: Border(
      top: BorderSide(color: Color(0xFFE0E0E0), width: 0.8),
    ),
  ),
  child: BottomNavigationBar(
  currentIndex: _bottomIndex,
  type: BottomNavigationBarType.fixed,
  backgroundColor: Colors.white,
  elevation: 0,

  // 🔥 THIS FIXES BLUE TEXT
  selectedItemColor: const Color(0xFFEA6B6B),
  unselectedItemColor: Colors.black54,

  showUnselectedLabels: true,

  selectedLabelStyle: GoogleFonts.poppins(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
  ),
  unselectedLabelStyle: GoogleFonts.poppins(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.2,
  ),
 onTap: (index) {
  if (index == _bottomIndex) return;

  Widget? destination;

  switch (index) {
            case 0:
              destination = const NewsFeedScreen();
              break;
            case 1:
              destination = const IndexScreen();
              break;
            case 2:
              destination = const ChatbotScreen();
              break;
            case 3:
              destination = const EventsScreen();
              break;
            case 4:
              destination = const SavedNewsFeedScreen();
              break;
            default:
              return;
          }

  // if (_interstitialAd != null && !_isShowingAd) {
  //   _isShowingAd = true;
  //   _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
  //     onAdDismissedFullScreenContent: (ad) {
  //       ad.dispose();
  //       _isShowingAd = false;
  //       _loadInterstitialAd();
  //       if (mounted) {
  //         Navigator.pushReplacement(
  //           context,
  //           MaterialPageRoute(builder: (_) => destination!),
  //         );
  //       }
  //     },
  //     onAdFailedToShowFullScreenContent: (ad, error) {
  //       ad.dispose();
  //       _isShowingAd = false;
  //       _loadInterstitialAd();
  //       if (mounted) {
  //         Navigator.pushReplacement(
  //           context,
  //           MaterialPageRoute(builder: (_) => destination!),
  //         );
  //       }
  //     },
  //   );
  //   _interstitialAd!.show();
  // } else {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => destination!),
    );
  // }
},
        items: [
          _navItem(label: "NEWS", active: 'assets/icons/News Red.svg', inactive: 'assets/icons/News.svg', index: 0),
          _navItem(label: "INDEX", active: 'assets/icons/Index red.svg', inactive: 'assets/icons/Index.svg', index: 1),
          _navItem(label: "ASK AI", active: 'assets/icons/Ask AI Red.svg', inactive: 'assets/icons/Ask AI.svg', index: 2),
          _navItem(label: "EVENTS", active: 'assets/icons/Calender Red.svg', inactive: 'assets/icons/Calender.svg', index: 3),
          _navItem(label: "SAVED", active: 'assets/icons/Save red.svg', inactive: 'assets/icons/Save.svg', index: 4),
        ],
),

),


    );
  }
}

class CorporateEvent {
  final String id;
  final String title;
  final DateTime date;
  final String description;
  final String type;
  final String tags;
  final String headline;

  CorporateEvent({
    required this.id,
    required this.title,
    required this.date,
    required this.description,
    required this.type,
    required this.tags,
    required this.headline,
  });

  factory CorporateEvent.fromJson(Map<String, dynamic> json) {
    return CorporateEvent(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? 'Untitled Event',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      description: json['description'] ?? '',
      type: json['type'] ?? 'Event',
      tags: json['tags'] ?? '',
      headline: json['headline'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'description': description,
      'type': type,
      'tags': tags,
      'headline': headline,
    };
  }
}

