import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:news_application/screens/saved_screen.dart';
import 'package:news_application/screens/profile_screen.dart';
import 'chatbot_screen.dart';
import '../models/article.dart';

import 'events_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'company_news_screen.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'index_screen.dart';


class NewsFeedScreen extends StatefulWidget {
  final String? openFileName;

  const NewsFeedScreen({super.key, this.openFileName});


  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> 
with WidgetsBindingObserver{
  final TextEditingController _searchController = TextEditingController();

  List<Article> _articles = [];
  List<Article> _filtered = [];
  List<Map<String, dynamic>> _allCompanies = [];
List<Map<String, dynamic>> _filteredCompanies = [];

  bool _isLoading = false;
  String _error = '';
  int _bottomIndex = 0;
  int _tabIndex = 0;
 Set<String> _locallySavedIds = {};
late String currentUserId;
bool _hasLoadedOnce = false;
late final PageController _pageController;
bool _isShowingAd = false;
Set<String> _viewedArticles = {};
// List<NativeAd> _nativeAds = [];
// BannerAd? _bannerAd;
// InterstitialAd? _interstitialAd;

int _viewCount = 0;

DateTime _lastTrackedDate = DateTime.now();


final String baseUrl = "http://51.20.136.45:5000";

 @override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  _bottomIndex = 0; 
  _searchController.addListener(_applySearch);
  _pageController = PageController(viewportFraction: 0.72);

  _init();
  // _loadInterstitialAd();
  // _loadNativeAd();
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
// void _showInterstitialAd() {
//   if (_isShowingAd) return;

//   if (_interstitialAd != null) {
//     _isShowingAd = true;

//     _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
//       onAdDismissedFullScreenContent: (ad) {
//         ad.dispose();
//         _isShowingAd = false;
//         _loadInterstitialAd();
//       },
//       onAdFailedToShowFullScreenContent: (ad, error) {
//         ad.dispose();
//         _isShowingAd = false;
//         _loadInterstitialAd();
//       },
//     );

//     _interstitialAd!.show();
//   }
// }
// void _loadNativeAd() {
//   for (int i = 0; i < 3; i++) {
//     final ad = NativeAd(
//       adUnitId: 'ca-app-pub-6088749573646337/3774928437', // test id
//       factoryId: 'listTile',
//       request: const AdRequest(),
//       listener: NativeAdListener(
//         onAdLoaded: (ad) {
//           setState(() {
//             _nativeAds.add(ad as NativeAd);
//           });
//         },
//         onAdFailedToLoad: (ad, error) {
//           ad.dispose();
//         },
//       ),
//     );

//     ad.load();
//   }
// }
Future<void> _init() async {
  await _loadUserId();
  await _fetchLatestNews();
  await _fetchCompanies();   // 🔥 ADD THIS
  await _loadSavedNewsIds();
}



@override
void dispose() {
  WidgetsBinding.instance.removeObserver(this);
  _searchController.removeListener(_applySearch);
  _searchController.dispose();
  _pageController.dispose();
  // _interstitialAd?.dispose();
  // for (var ad in _nativeAds) {
  //   ad.dispose();
  // }
  super.dispose();
}

@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed && _hasLoadedOnce) {
    switch (_tabIndex) {
      case 0:
        _fetchLatestNews(soft: true);
        break;
      case 1:
        _fetchTrendingNews();
        break;
      case 2:
        _fetchGlobalNews();
        break;
      case 3:
        _fetchCommoditiesNews();
        break;
    }
  }
}

Future<void> _fetchCompanies() async {
  try {
    final resp = await http.get(Uri.parse("$baseUrl/api/companies"));

    if (resp.statusCode == 200) {
      final body = json.decode(resp.body);

      setState(() {
        _allCompanies =
            List<Map<String, dynamic>>.from(body["data"]);
        _filteredCompanies = [];
      });
    }
  } catch (e) {
    debugPrint("Company fetch failed: $e");
  }
}

List<Article> _removeDuplicates(List<Article> list) {
  final map = <String, Article>{};
  final seen = <String>{};
  
  for (var a in list) {
    // Remove by ID first
    if (map.containsKey(a.id)) continue;
    
    // Check for similar content
    final contentKey = _generateContentKey(a);
    if (seen.contains(contentKey)) continue;
    
    map[a.id] = a;
    seen.add(contentKey);
  }
  return map.values.toList();
}

String _generateContentKey(Article a) {
  // Normalize title: lowercase, remove special chars, trim
  final normalizedTitle = a.title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.length > 3) // Keep only meaningful words
      .take(10) // First 10 words
      .join(' ');
  
  // Use first 100 chars of summary for additional matching
  final summarySnippet = a.summary.length > 100 
      ? a.summary.substring(0, 100).toLowerCase() 
      : a.summary.toLowerCase();
  
  return '$normalizedTitle|$summarySnippet';
}

void _scrollToArticle(String fileName) {
  final index = _filtered.indexWhere(
    (a) => a.fileName == fileName,
  );

  if (index != -1) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!_pageController.hasClients) return;

      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }
}



Future<void> _trackNewsView() async {
  if (currentUserId.isEmpty) return;

  final now = DateTime.now();
  final date = DateFormat("yyyy-MM-dd").format(now);

  try {
    await http.post(
      Uri.parse("$baseUrl/api/users/profile/news-analytics"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "userId": currentUserId,
        "date": date,
      }),
    );
  } catch (e) {
    debugPrint("News analytics error: $e");
  }

  _lastTrackedDate = now;
}




  // ------------------------- SEARCH -------------------------
  Future<void> _loadUserId() async {
  final prefs = await SharedPreferences.getInstance();
  currentUserId = prefs.getString("userId") ?? "";
}

void _applySearch() {
  final q = _searchController.text.trim().toLowerCase();

  if (q.isEmpty) {
    setState(() {
      _filtered = List.from(_articles);
      _filteredCompanies = [];  // 🔥 Clear companies
    });
    return;
  }

  setState(() {
    // 🔹 Filter Articles
    _filtered = _articles.where((a) {
      final hay =
          '${a.title} ${a.excerpt} ${a.tags.join(' ')}'.toLowerCase();
      return hay.contains(q);
    }).toList();

    // 🔹 Filter Companies
    _filteredCompanies = _allCompanies.where((company) {
      final name =
          (company["Company Name"] ?? "").toLowerCase();
      final symbol =
          (company["Symbol"] ?? "").toLowerCase();
      return name.contains(q) || symbol.contains(q);
    }).toList();
  });
}


  // ------------------------- FETCH LATEST -------------------------
 Future<void> _fetchLatestNews({bool soft = false}) async {
  _startLoading(soft: soft);

  try {
    final resp = await http.get(Uri.parse("$baseUrl/api/news"));

    if (resp.statusCode == 200) {
      final decoded = json.decode(resp.body);

      List data;

      if (decoded is List) {
        data = decoded;
      } else if (decoded is Map && decoded["data"] != null) {
        data = decoded["data"];
      } else {
        data = [];
      }

      _articles = _removeDuplicates(
        data.map((e) => Article.fromJson(e)).toList(),
      );

      _articles.sort((a, b) => b.date.compareTo(a.date));
      _filtered = List.from(_articles);

      if (widget.openFileName != null &&
          widget.openFileName!.isNotEmpty) {
        _scrollToArticle(widget.openFileName!);
      }

    } else {
      _error = "Failed to load latest news";
    }

  } catch (e) {
    _error = "Error: $e";
  }

  _stopLoading();
  _hasLoadedOnce = true;
}

  Future<List<Map<String, dynamic>>> _fetchCompanyDetails(
    List<String> companyNames) async {

  final names = companyNames.join(",");
  final url =
      "$baseUrl/api/company-lookup/by-names?names=$names";

  debugPrint("TradingView API URL: $url");

  final resp = await http.get(Uri.parse(url));

  debugPrint("TradingView API status: ${resp.statusCode}");
  debugPrint("TradingView API body: ${resp.body}");

  if (resp.statusCode != 200) {
    throw Exception("Failed to fetch company details");
  }

  final body = jsonDecode(resp.body);
  return List<Map<String, dynamic>>.from(body["data"]);
}

Future<Map<String, dynamic>?> _fetchSectorDetails(String sector) async {
  final url =
      "$baseUrl/api/sector-lookup/by-name?name=$sector";

  final resp = await http.get(Uri.parse(url));

  if (resp.statusCode != 200) return null;

  final body = jsonDecode(resp.body);

  if (!body["success"]) return null;

  return body["data"];
}
Future<Map<String, dynamic>?> _fetchCommodityDetails(String commodity) async {
  final url =
      "$baseUrl/api/commodity-lookup/by-name?name=$commodity";

  final resp = await http.get(Uri.parse(url));

  if (resp.statusCode != 200) return null;

  final body = jsonDecode(resp.body);

  if (!body["success"]) return null;

  return body["data"];
}


Future<void> _openTradingView(String fullSymbol) async {
  final url =
      "https://www.tradingview.com/chart/?symbol=$fullSymbol";

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
           subtitle: Text("${c["exchange"]}:${c["symbol"]}"),
          onTap: () {
  Navigator.pop(context);
  _openTradingView(
    "${c["exchange"]}:${c["symbol"]}",
  );
},

          ),
        ),
      ],
    ),
  );
}

void _showCommoditySelector(List<Map<String, dynamic>> commodities) {
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
        ...commodities.map(
          (c) => ListTile(
            title: Text(c["name"]),
            subtitle: Text(c["symbol"]),
            onTap: () {
              Navigator.pop(context);
              _openTradingView(
                c["symbol"].toString(),
              );
            },
          ),
        ),
      ],
    ),
  );
}


  // ------------------------- FETCH TRENDING -------------------------
  Future<void> _fetchTrendingNews() async {
    _startLoading();

    try {
      final resp =
          await http.get(Uri.parse("$baseUrl/api/trending-news"));

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
       _articles = _removeDuplicates(
            (body['data'] as List).map((e) => Article.fromJson(e)).toList(),
          );

        
        _sortByLatest();
      } else {
        _error = "Failed to load trending news";
      }
    } catch (e) {
      _error = "Error: $e";
    }
    _hasLoadedOnce = true;


    _stopLoading();
  }

  void _startLoading({bool soft = false}) {
  setState(() {
    if (!soft) {
      _isLoading = true;
      _articles = [];
      _filtered = [];
    }
    _error = '';
  });
}


  void _stopLoading() {
    setState(() => _isLoading = false);
  }
  // ------------------------- FETCH GLOBAL -------------------------
Future<void> _fetchGlobalNews() async {
  _startLoading();

  try {
    final resp =
        await http.get(Uri.parse("$baseUrl/api/global-news"));

    if (resp.statusCode == 200) {
      final body = json.decode(resp.body);
      _articles = _removeDuplicates(
  (body['data'] as List).map((e) => Article.fromJson(e)).toList(),
);
      
      _sortByLatest();
    } else {
      _error = "Failed to load global news";
    }
  } catch (e) {
    _error = "Error: $e";
  }
  _hasLoadedOnce = true;

  _stopLoading();
}

// ------------------------- FETCH COMMODITIES -------------------------
Future<void> _fetchCommoditiesNews() async {
  _startLoading();

  try {
    final resp =
        await http.get(Uri.parse("$baseUrl/api/commodities-news"));

    if (resp.statusCode == 200) {
      final body = json.decode(resp.body);
      _articles = _removeDuplicates(
  (body['data'] as List).map((e) => Article.fromJson(e)).toList(),
);

      
      _sortByLatest();
    } else {
      _error = "Failed to load commodities news";
    }
  } catch (e) {
    _error = "Error: $e";
  }
  _hasLoadedOnce = true;

  _stopLoading();
}

Future<void> _loadSavedNewsIds() async {
  if (currentUserId.isEmpty) return;

  try {
    final resp = await http.get(
      Uri.parse("$baseUrl/api/users/$currentUserId/saved-news"),
    );

    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      final List saved = body["data"];

      setState(() {
        _locallySavedIds = saved.map((e) {
  final id = e["newsId"];

  if (id is Map && id["_id"] != null) {
    return id["_id"].toString();
  }

  return id.toString();
}).toSet();
      });
    }
  } catch (e) {
    debugPrint("Failed to load saved ids: $e");
  }
}

Future<void> _toggleSaveNews(Article a) async {
  final bool wasSaved = _locallySavedIds.contains(a.id);

  // 1️⃣ Optimistic UI
  setState(() {
    if (wasSaved) {
      _locallySavedIds.remove(a.id.toString());
    } else {
      _locallySavedIds.add(a.id.toString());
    }
  });

  try {
    final resp = await http.post(
      Uri.parse("$baseUrl/api/users/save-news"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "userId": currentUserId,
        "newsId": a.id,
        "headline": a.title,
        "summary": a.summary,
        "story": a.story,
        "companys": a.companies,
        "commodities_market": a.commodities_market,
        "sector_market": a.sector_market,
        "sentiment": a.sentiment,
        "impact": a.impact,
      }),
    );

    if (resp.statusCode != 200) {
      throw Exception("API failed");
    }
  } catch (e) {
    // rollback
    setState(() {
      if (wasSaved) {
        _locallySavedIds.add(a.id);
      } else {
        _locallySavedIds.remove(a.id);
      }
    });

    debugPrint("Save toggle failed: $e");
  }
}

  // ------------------------- TAB HANDLER -------------------------
  void _onTabChange(int idx) {
  setState(() => _tabIndex = idx);

  switch (idx) {
    case 0:
      _fetchLatestNews();
      break;
    case 1:
      _fetchTrendingNews();
      break;
    case 2:
      _fetchGlobalNews();
      break;
    case 3:
      _fetchCommoditiesNews();
      break;
  }
}
void _sortByLatest() {
  _articles.sort((a, b) => b.date.compareTo(a.date));
  _filtered = List.from(_articles);
}


  // ------------------------- SHOW FULL STORY -------------------------
 Future<void> _showFullStory(Article a) async {
  Color sentimentColor(String s) {
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
        return Colors.grey;
    }
  }

  Color impactColor(String i) {
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
        return Colors.grey;
    }
  }

  showDialog(
  context: context,
  barrierDismissible: true,
  builder: (ctx) => Dialog(
    backgroundColor: Colors.white, // ✅ WHITE BACKGROUND
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// ---------------- TITLE ----------------
          Text(
            a.title,
            style: GoogleFonts.poppins(
              fontSize: 16,           // ✅ SAME AS CARD TITLE
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 12),

          /// ---------------- FULL STORY ----------------
          if (a.story.isNotEmpty) ...[
            Html(
              data: a.story,
              style: {
                "p": Style(
                  fontFamily: GoogleFonts.poppins().fontFamily,
                  fontSize: FontSize(14.5), // ✅ SAME AS CARD SUMMARY
                  lineHeight: LineHeight.number(1.4),
                  color: Colors.black87,
                  margin: Margins.only(bottom: 12),
                ),
              },
            ),
            const SizedBox(height: 8),
          ],

          /// ---------------- SENTIMENT ----------------
          if (a.sentiment.isNotEmpty)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: "Sentiment: ",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  TextSpan(
                    text: a.sentiment,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: sentimentColor(a.sentiment),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 6),

          /// ---------------- IMPACT ----------------
          if (a.impact.isNotEmpty)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: "Impact: ",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  TextSpan(
                    text: a.impact,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: impactColor(a.impact),
                    ),
                  ),
                ],
              ),
            ),

          /// ---------------- COMPANIES ----------------
          /// ---------------- MARKET INFORMATION ----------------
if (a.companies.isNotEmpty) ...[
  const SizedBox(height: 14),

  Text(
    "Companies",
    style: GoogleFonts.poppins(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Colors.black,
    ),
  ),

  const SizedBox(height: 8),

  Wrap(
    spacing: 8,
    runSpacing: 8,
    children: a.companies.map(
      (company) => Chip(
        backgroundColor: const Color(0xFFEA6B6B),
        label: Text(
          company,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    ).toList(),
  ),
]

else if (a.sector_market.isNotEmpty) ...[
  const SizedBox(height: 14),

  Text(
    "Sector",
    style: GoogleFonts.poppins(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Colors.black,
    ),
  ),

  const SizedBox(height: 8),

  Chip(
    backgroundColor: const Color(0xFFEA6B6B),
    label: Text(
  a.sector_market,
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
  ),
]

else if (a.commodities_market.isNotEmpty) ...[
  const SizedBox(height: 14),

  Text(
    "Commodity",
    style: GoogleFonts.poppins(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Colors.black,
    ),
  ),

  const SizedBox(height: 8),

  Wrap(
    spacing: 8,
    runSpacing: 8,
    children: a.commodities_market.map(
      (commodity) => Chip(
        backgroundColor: const Color(0xFFEA6B6B),
        label: Text(
          commodity,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    ).toList(),
  ),
],


          const SizedBox(height: 18),

          /// ---------------- CLOSE BUTTON ----------------
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                "Close",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFEA6B6B),
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


  // ------------------------- UI -------------------------
  Widget _buildTopSearchRow() {
    final screenWidth = MediaQuery.of(context).size.width;

final bool isSmallPhone = screenWidth < 360;
final bool isTablet = screenWidth > 600;
    return Container(
      height: isTablet
    ? 64
    : (isSmallPhone ? 48 : 56),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          
          
          
          // Search Bar
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Color(0xFFB7B7B7), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      cursorColor: const Color(0xFFE54350),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: const Color(0xFF333333),
                      ),
                      decoration: InputDecoration(
                        hintText: "Search here...",
                        hintStyle: GoogleFonts.manrope(
                          fontSize: 12,
                          color: const Color(0xFFB7B7B7),
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Profile Avatar
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
            child: const CircleAvatar(
              radius: 20,
              backgroundColor: Color(0xFFE0E0E0),
              child: Icon(
                Icons.person,
                size: 20,
                color: Color(0xFF757575),
              ),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildTabsRow() {
  final tabs = ["LATEST", "TRENDING", "GLOBAL", "COMMODITIES"];
  final screenWidth = MediaQuery.of(context).size.width;
  final bool isSmallPhone = screenWidth < 360;
  final bool isTablet = screenWidth > 600;

  return Container(
    color: Colors.white,
    child: Column(
      children: [
        SizedBox(
          height: isTablet ? 52 : (isSmallPhone ? 42 : 47),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 20 : 16),
            itemCount: tabs.length,
            itemBuilder: (context, idx) {
              final selected = idx == _tabIndex;

              return GestureDetector(
                onTap: () => _onTabChange(idx),
                child: Padding(
                  padding: EdgeInsets.only(right: isTablet ? 24 : 18),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tabs[idx],
                        style: GoogleFonts.manrope(
                          fontSize: isTablet ? 14 : (isSmallPhone ? 11 : 12),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.65,
                          height: 19.5 / 12,
                          color: selected
                              ? const Color(0xFFE54350)
                              : const Color(0xFF9AA0AE),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        height: 1.5,
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFE54350)
                              : Colors.transparent,
                        ),
                        width: _textWidth(
                              tabs[idx],
                              GoogleFonts.manrope(
                                fontSize: isTablet ? 14 : (isSmallPhone ? 11 : 12),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.65,
                              ),
                            ) -
                            4,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1, thickness: 0.6, color: Color(0xFFE9E9E9)),
      ],
    ),
  );
}


double _textWidth(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: Directionality.of(context), // ✅ FIX
  )..layout();

  return painter.size.width;
}



  Widget _buildFeed() {
  if (_isLoading) {
    return const Expanded(
      child: Center(child: CircularProgressIndicator(color: Color(0xFFE54350))),
    );
  }

  if (_error.isNotEmpty) {
    return Expanded(child: Center(child: Text(_error)));
  }

  if (_filtered.isEmpty) {
    return const Expanded(child: Center(child: Text("No articles found")));
  }

  return Expanded(
    child: RefreshIndicator(
      onRefresh: () {
        switch (_tabIndex) {
          case 0:
            return _fetchLatestNews();
          case 1:
            return _fetchTrendingNews();
          case 2:
            return _fetchGlobalNews();
          case 3:
            return _fetchCommoditiesNews();
          default:
            return _fetchLatestNews();
        }
      },

     child: _searchController.text.isEmpty

    /// 🔥 NORMAL MODE (KEEP PAGEVIEW)
    ? PageView.builder(
  scrollDirection: Axis.vertical,
  controller: _pageController,
  padEnds: false,
  physics: const BouncingScrollPhysics(),
  itemCount: _filtered.length, // + (_filtered.length ~/ 5),
  itemBuilder: (context, index) {

    // 🔥 Native Ad
   // if (index != 0 && index % 5 == 0 && _nativeAds.isNotEmpty) {

  // 🔥 ADD THIS LINE HERE
  // final adIndex = (index ~/ 5) % _nativeAds.length;

  // return SizedBox(
  //   height: MediaQuery.of(context).size.height * 0.75,
  //   child: Container(
  //     margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  //     padding: const EdgeInsets.all(16),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(14),
  //       boxShadow: [
  //         BoxShadow(
  //           color: Colors.black.withOpacity(0.04),
  //           blurRadius: 8,
  //           offset: const Offset(0, 3),
  //         ),
  //       ],
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         const Text(
  //           "Sponsored",
  //           style: TextStyle(fontSize: 12, color: Colors.grey),
  //         ),
  //         const SizedBox(height: 8),

  //         Expanded(
  //           child: AdWidget(
  //             ad: _nativeAds[adIndex], // ✅ USE HERE
  //           ),
  //         ),
  //       ],
  //     ),
  //   ),
  // );
// }

    // int articleIndex = index - (index ~/ 5);
    final article = _filtered[index];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: VisibilityDetector(
        key: Key(article.id),
        onVisibilityChanged: (info) {
          if (info.visibleFraction > 0.6 &&
              !_viewedArticles.contains(article.id)) {
            _viewedArticles.add(article.id);
            _trackNewsView();
          }
        },
        child: _buildArticleCard(article),
      ),
    );
  },
)
    /// 🔎 SEARCH MODE (SHOW LISTVIEW)
    : ListView(
        children: [

          /// Companies
          if (_filteredCompanies.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Text(
                "Companies",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            ..._filteredCompanies.map(
              (company) => CompanySearchCard(
                companyName:
                    company["Company Name"] ?? "Unknown",
                symbol: company["Symbol"] ?? "",
              ),
            ),
          ],

          /// News
          if (_filtered.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Text(
                "News",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            ..._filtered.map(
  (article) => _buildSearchArticleCard(article),
),

          ],

          if (_filtered.isEmpty &&
              _filteredCompanies.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text("No results found"),
              ),
            ),
        ],
      ),


    ),
  );
}
Widget _buildSearchArticleCard(Article a) {
  final dateFormatted =
      DateFormat.yMMMd().add_jm().format(a.date);

  Color sentimentColor(String s) {
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
        return Colors.grey;
    }
  }

  Color impactColor(String i) {
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
        return Colors.grey;
    }
  }

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _showFullStory(a),
      child: Container(
        margin:
            const EdgeInsets.symmetric(horizontal: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,

  borderRadius: BorderRadius.circular(16),

  border: Border.all(
    color: const Color(0xFFE5E7EB),
    width: 1,
  ),
          boxShadow: [
  BoxShadow(
    color: Colors.black.withOpacity(0.08),
    blurRadius: 12,
    spreadRadius: 1,
    offset: const Offset(0, 4),
  ),
],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // 🔥 KEY FIX
          children: [
            Text(
              a.title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              a.summary,
              style: GoogleFonts.poppins(
                fontSize: 15,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 12),

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
                        color: sentimentColor(a.sentiment),
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
                        color: impactColor(a.impact),
                      ),
                    ),
                  ],
                ),
              ),


            const SizedBox(height: 8),

            Text(
              dateFormatted,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildArticleCard(Article a) {
  final screenWidth = MediaQuery.of(context).size.width;

final bool isSmallPhone = screenWidth < 360;
final bool isTablet = screenWidth > 600;
  final dateFormatted = DateFormat.yMMMd().add_jm().format(a.date);

  Color sentimentColor(String s) {
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
        return Colors.grey;
    }
  }

  Color impactColor(String i) {
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
        return Colors.grey;
    }
  }

  Color sentimentBgColor(String s) {
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

  Color sentimentBorderColor(String s) {
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

  Color impactBgColor(String i) {
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

  Color impactBorderColor(String i) {
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

  return Padding(
  padding: const EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 8,
  ),

    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showFullStory(a),
      child: Container(
        margin: EdgeInsets.symmetric(
  horizontal:
      MediaQuery.of(context).size.width * 0.04,
  vertical: 8,
),
       padding: EdgeInsets.all(
  isTablet ? 18 : (isSmallPhone ? 12 : 14),
),
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

            /// TITLE
            Text(
            a.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize:
                  isTablet ? 20 : (isSmallPhone ? 15 : 17),
                fontWeight: FontWeight.w800,
                color: const Color(0xFF333333),
              ),
            ),

            const SizedBox(height: 10),

            /// SUMMARY (Scrollable if long)
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  a.summary,
                  textAlign: TextAlign.start,
                  style: GoogleFonts.manrope(
                    fontSize:
    isTablet ? 16 : (isSmallPhone ? 13 : 14),
                    fontWeight: FontWeight.w400,
                    height: 1.6,
                    color: const Color(0xFF555555),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            /// MARKET TAG
            if (a.companies.isNotEmpty)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "Companies: ",
                      style: GoogleFonts.dmSans(
                        fontSize:
    isTablet ? 17 : (isSmallPhone ? 14 : 15.5),
                        fontWeight: FontWeight.w700,
                        height: 20 / 14,
                        color: const Color(0xFF555555),
                      ),
                    ),
                    TextSpan(
                      text: a.companies.join(', '),
                      style: GoogleFonts.dmSans(
                        fontSize:
    isTablet ? 17 : (isSmallPhone ? 14 : 15.5),
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
                        fontSize:
    isTablet ? 17 : (isSmallPhone ? 14 : 15.5),
                        fontWeight: FontWeight.w700,
                        height: 20 / 14,
                        color: const Color(0xFF555555),
                      ),
                    ),
                    TextSpan(
                      text: a.sector_market,
                      style: GoogleFonts.dmSans(
                        fontSize:
    isTablet ? 17 : (isSmallPhone ? 14 : 15.5),
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
                        fontSize:
    isTablet ? 17 : (isSmallPhone ? 14 : 15.5),
                        fontWeight: FontWeight.w700,
                        height: 20 / 14,
                        color: const Color(0xFF555555),
                      ),
                    ),
                    TextSpan(
                      text: a.commodities_market.join(', '),
                      style: GoogleFonts.dmSans(
                        fontSize:
    isTablet ? 17 : (isSmallPhone ? 14 : 15.5),
                        fontWeight: FontWeight.w500,
                        height: 20 / 14,
                        color: const Color(0xFF555555),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 6),

            /// SENTIMENT CHIP
            if (a.sentiment.isNotEmpty)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "Sentiment: ",
                      style: GoogleFonts.dmSans(
                        fontSize:
    isTablet ? 17 : (isSmallPhone ? 14 : 15.5),
                        fontWeight: FontWeight.w700,
                        height: 20 / 14,
                        letterSpacing: 0,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    TextSpan(
                      text: a.sentiment,
                      style: GoogleFonts.dmSans(
                        fontSize:
    isTablet ? 17 : (isSmallPhone ? 14 : 15.5),
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

            /// IMPACT CHIP
            if (a.impact.isNotEmpty)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: "Impact: ",
                      style: GoogleFonts.dmSans(
                       fontSize:
    isTablet ? 17 : (isSmallPhone ? 14 : 15.5),
                        fontWeight: FontWeight.w700,
                        height: 20 / 14,
                        letterSpacing: 0,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    TextSpan(
                      text: a.impact,
                      style: GoogleFonts.dmSans(
                        fontSize:
    isTablet ? 17 : (isSmallPhone ? 14 : 15.5),
                        fontWeight: FontWeight.w500,
                        height: 20 / 14,
                        color: _getImpactColor(a.impact),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 10),

            /// FOOTER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                /// DATE
                Text(
                  dateFormatted,
                  style: GoogleFonts.manrope(
                    fontSize:
    isTablet ? 12 : (isSmallPhone ? 10 : 11),
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF8A8A8A),
                  ),
                ),

                /// ACTIONS
                Row(
                  children: [

                    /// TRADINGVIEW
                    if (a.companies.isNotEmpty ||
                        a.sector_market.isNotEmpty ||
                        a.commodities_market.isNotEmpty)
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Image.asset(
                          "assets/tradingview.png",
                          height:
    isTablet ? 34 : (isSmallPhone ? 24 : 28),

width:
    isTablet ? 34 : (isSmallPhone ? 24 : 28),
                        ),
                        onPressed: () async {
                          try {

                            if (a.companies.isNotEmpty) {
                              final companies =
                                  await _fetchCompanyDetails(a.companies);

                              if (companies.isEmpty) return;

                              if (companies.length == 1) {
                                _openTradingView(
                                  "${companies.first["exchange"]}:${companies.first["symbol"]}",
                                );
                              } else {
                                _showCompanySelector(companies);
                              }
                              return;
                            }

                            if (a.sector_market.isNotEmpty) {
                              final sector =
                                  await _fetchSectorDetails(a.sector_market);

                              if (sector != null) {
                                _openTradingView(
                                  "NSE:${sector["symbol"]}",
                                );
                              }
                              return;
                            }

                            if (a.commodities_market.isNotEmpty) {
                              final List<Map<String, dynamic>> commodityList = [];

                              for (String name in a.commodities_market) {
                                final data =
                                    await _fetchCommodityDetails(name);
                                if (data != null) {
                                  commodityList.add(data);
                                }
                              }

                              if (commodityList.isEmpty) return;

                              if (commodityList.length == 1) {
                                _openTradingView(
                                  commodityList.first["symbol"].toString(),
                                );
                              } else {
                                _showCommoditySelector(commodityList);
                              }
                            }

                          } catch (e) {
                            debugPrint("TradingView error: $e");
                          }
                        },
                      ),

                    const SizedBox(width: 6),

                    /// SAVE
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        _locallySavedIds.contains(a.id)
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        size:
    isTablet ? 34 : (isSmallPhone ? 24 : 28),
                        color: _locallySavedIds.contains(a.id)
                            ? const Color(0xFFE54350)
                            : const Color(0xFF8A8A8A),
                      ),
                      onPressed: () => _toggleSaveNews(a),
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
      height: 20,
    ),
    label: label,
    tooltip: label,
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




  // ------------------------- BUILD -------------------------
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
final screenHeight = MediaQuery.of(context).size.height;

final bool isSmallPhone = screenWidth < 360;
final bool isTablet = screenWidth > 600;

final double titleFont =
    isTablet ? 20 : (isSmallPhone ? 15 : 17);

final double summaryFont =
    isTablet ? 16 : (isSmallPhone ? 13 : 14);

final double sentimentFont =
    isTablet ? 17 : (isSmallPhone ? 14 : 15.5);

final double dateFont =
    isTablet ? 12 : (isSmallPhone ? 10 : 11);

final double cardPadding =
    isTablet ? 18 : (isSmallPhone ? 12 : 14);
    return Scaffold(
      resizeToAvoidBottomInset: false, 
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopSearchRow(),
            _buildTabsRow(),
            const SizedBox(height: 10),
            _buildFeed(),
          ],
        ),
      ),
     bottomNavigationBar: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
  top: BorderSide(
    color: Color(0xFFEAEAEA),
    width: 0.6,
  ),
),
      ),
      child: BottomNavigationBar(
        currentIndex: _bottomIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor:const Color(0xFFE54350),
        unselectedItemColor: const Color(0xFF6B7A99),
        showUnselectedLabels: true,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.0,
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

class CompanySearchCard extends StatelessWidget {
  final String companyName;
  final String symbol;

  const CompanySearchCard({
    super.key,
    required this.companyName,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CompanyNewsScreen(
                companyName: companyName,
                companySymbol: symbol,
              ),
            ),
          );
        },
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
  BoxShadow(
    color: Colors.black.withOpacity(0.08),
    blurRadius: 16,
    spreadRadius: 3,
    offset: Offset.zero,
  ),
],
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  companyName,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                symbol,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
