// lib/screens/events_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'home_screen.dart';
import 'chatbot_screen.dart';
import 'company_screen.dart';
import 'saved_screen.dart';
import 'profile_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/article_card.dart';
import '../models/article.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'index_screen.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';



class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}


class _EventsScreenState extends State<EventsScreen> {
  int _selectedTab = 0;
  final List<String> _tabs = ["Today", "Upcoming","Upcoming IPO"];
  
  bool _isLoading = true;
  List<CorporateEvent> _todayEvents = [];
  List<CorporateEvent> _upcomingEvents = [];
  Set<String> _locallySavedEventIds = {};
  late String currentUserId;
  int _bottomIndex = 3;
  List<Article> _ipoNews = [];
  bool _isIpoLoading = false;
  Set<String> _locallySavedIds = {};
  final String baseUrl = "http://51.20.136.45:5000";
  late final PageController _pageController;
  Set<String> _viewedArticles = {};
  DateTime _lastTrackedDate = DateTime.now();
  String? _expandedEventId; // Track which event card is expanded
  // InterstitialAd? _interstitialAd;
  // bool _isShowingAd = false;


@override
void initState() {
  super.initState();
  _pageController = PageController(viewportFraction: 0.72);
  // _loadInterstitialAd();

  _loadUserId().then((_) {
    _loadSavedEventIds();
    _loadSavedNewsIds();
    _fetchEvents();
    _fetchIpoNews();
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
  _pageController.dispose();
  // _interstitialAd?.dispose();
  super.dispose();
}

Future<void> _loadUserId() async {
  final prefs = await SharedPreferences.getInstance();
  currentUserId = prefs.getString("userId") ?? "";
}

Future<void> _loadSavedEventIds() async {
  final resp = await http.get(
    Uri.parse("http://51.20.136.45:5000/api/users/$currentUserId/saved-events"),
  );

  if (resp.statusCode == 200) {
    final body = jsonDecode(resp.body);
    setState(() {
      _locallySavedEventIds =
          body["data"].map<String>((e) => e["_id"].toString()).toSet();
    });
  }
}


  Future<void> _fetchEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('Fetching events from: http://10.244.218.93:5000/api/events');
      
      final response = await http.get(
        Uri.parse('http://51.20.136.45:5000/api/events'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['events'] == null || (data['events'] as List).isEmpty) {
          debugPrint('No events found in response');
          setState(() {
            _todayEvents = [];
            _upcomingEvents = [];
            _isLoading = false;
          });
          return;
        }
        
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        final List<CorporateEvent> allEvents = (data['events'] as List)
            .map((event) => CorporateEvent.fromJson(event))
            .toList();

        debugPrint('Total events fetched: ${allEvents.length}');

        _todayEvents = allEvents.where((event) {
          final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
          return eventDate.isAtSameMomentAs(today);
        }).toList();

        _upcomingEvents = allEvents.where((event) {
          final eventDate = DateTime(event.date.year, event.date.month, event.date.day);
          return eventDate.isAfter(today);
        }).toList();

        debugPrint('Today events: ${_todayEvents.length}');
        debugPrint('Upcoming events: ${_upcomingEvents.length}');

        setState(() {
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load events: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching events: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading events: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _fetchEvents,
            ),
          ),
        );
      }
    }
  }

Future<void> _fetchIpoNews() async {
  setState(() {
    _isIpoLoading = true;
  });

  try {
    final response = await http.get(
      Uri.parse("$baseUrl/api/news/sector/IPO"),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      setState(() {
        _ipoNews = (data["news"] as List)
            .map((e) => Article.fromJson(e))
            .toList();
        _isIpoLoading = false;
      });
    } else {
      throw Exception("Failed to load IPO news");
    }
  } catch (e) {
    setState(() {
      _isIpoLoading = false;
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


Future<void> _toggleSaveEvent(CorporateEvent event) async {
  final eventId = event.id;
  final wasSaved = _locallySavedEventIds.contains(eventId);

  // 1️⃣ Optimistic UI
  setState(() {
    wasSaved
        ? _locallySavedEventIds.remove(eventId)
        : _locallySavedEventIds.add(eventId);
  });

  try {
    final resp = await http.post(
      Uri.parse("http://51.20.136.45:5000/api/users/save-event"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "userId": currentUserId,
        "eventId": eventId,
      }),
    );

    if (resp.statusCode != 200) throw Exception();

    // ✅ ONLY WHEN SAVED (NOT UNSAVED)
    if (!wasSaved) {
      // 2️⃣ Success Snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Event saved successfully"),
          duration: Duration(seconds: 2),
        ),
      );

      // 3️⃣ Ask to add to Google Calendar
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Add to Google Calendar"),
          content: const Text(
              "Do you want to add this event to your Google Calendar?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("No"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                addEventToGoogleCalendar(
                  title: event.title,
                  description: event.description,
                  startTime: event.date,
                  endTime: event.date.add(const Duration(hours: 1)),
                );
              },
              child: const Text("Yes"),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    // 🔁 Rollback UI
    setState(() {
      wasSaved
          ? _locallySavedEventIds.add(eventId)
          : _locallySavedEventIds.remove(eventId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Failed to save event"),
        backgroundColor: Colors.red,
      ),
    );
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

Future<void> _toggleSaveNews(Article a) async {
  final bool wasSaved = _locallySavedIds.contains(a.id.toString());

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



Widget _buildIpoTab() {
  if (_isIpoLoading) {
    return const Center(
      child: CircularProgressIndicator(color: Color(0xFFE54350)),
    );
  }

  if (_ipoNews.isEmpty) {
    return const Center(
      child: Text(
        "No IPO News Available",
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }

  return PageView.builder(
    scrollDirection: Axis.vertical,
    controller: _pageController,
    padEnds: false,
    physics: const BouncingScrollPhysics(),
    itemCount: _ipoNews.length,
    itemBuilder: (context, index) {
      final article = _ipoNews[index];

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
          child: _buildIpoArticleCard(article),
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar Header
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
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
                          const Icon(
                            Icons.search,
                            color: Color(0xFFB7B7B7),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
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
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    ),
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
            ),

            // Tabs
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  SizedBox(
                    height: 47,
                    child: Row(
                      children: _tabs.asMap().entries.map((entry) {
                        final index = entry.key;
                        final tab = entry.value;
                        final selected = _selectedTab == index;

                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedTab = index),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  tab.toUpperCase(),
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
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
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const Divider(height: 1, thickness: 0.6, color: Color(0xFFE9E9E9)),
                ],
              ),
            ),

            // Content based on selected tab
            Expanded(
              child: _selectedTab == 0
                  ? _buildTodayEventsTab()
                  : _selectedTab == 1
                      ? _buildUpcomingEventsTab()
                      : _buildIpoTab(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
  currentIndex: _bottomIndex,
  type: BottomNavigationBarType.fixed,
  backgroundColor: Colors.white,
  elevation: 0,

  selectedItemColor: const Color(0xFFE54350),
  unselectedItemColor: const Color(0xFF64748B),

  showUnselectedLabels: true,

  selectedLabelStyle: GoogleFonts.manrope(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.2,
  ),
  unselectedLabelStyle: GoogleFonts.manrope(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.2,
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
    );
  }

Widget _buildIpoArticleCard(Article a) {
  final screenWidth = MediaQuery.of(context).size.width;
  final bool isSmallPhone = screenWidth < 360;
  final bool isTablet = screenWidth > 600;
  final dateFormatted = DateFormat.yMMMd().add_jm().format(a.date);

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showFullStory(a),
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width * 0.04,
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
            Text(
              a.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(
                fontSize: isTablet ? 20 : (isSmallPhone ? 15 : 17),
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
                  textAlign: TextAlign.start,
                  style: GoogleFonts.manrope(
                    fontSize: isTablet ? 16 : (isSmallPhone ? 13 : 14),
                    fontWeight: FontWeight.w400,
                    height: 1.6,
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
                        fontSize: isTablet ? 17 : (isSmallPhone ? 14 : 15.5),
                        fontWeight: FontWeight.w700,
                        height: 20 / 14,
                        color: const Color(0xFF555555),
                      ),
                    ),
                    TextSpan(
                      text: a.companies.join(', '),
                      style: GoogleFonts.dmSans(
                        fontSize: isTablet ? 17 : (isSmallPhone ? 14 : 15.5),
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
                        fontSize: isTablet ? 17 : (isSmallPhone ? 14 : 15.5),
                        fontWeight: FontWeight.w700,
                        height: 20 / 14,
                        color: const Color(0xFF555555),
                      ),
                    ),
                    TextSpan(
                      text: a.sector_market,
                      style: GoogleFonts.dmSans(
                        fontSize: isTablet ? 17 : (isSmallPhone ? 14 : 15.5),
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
                        fontSize: isTablet ? 17 : (isSmallPhone ? 14 : 15.5),
                        fontWeight: FontWeight.w700,
                        height: 20 / 14,
                        color: const Color(0xFF555555),
                      ),
                    ),
                    TextSpan(
                      text: a.commodities_market.join(', '),
                      style: GoogleFonts.dmSans(
                        fontSize: isTablet ? 17 : (isSmallPhone ? 14 : 15.5),
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
                        fontSize: isTablet ? 17 : (isSmallPhone ? 14 : 15.5),
                        fontWeight: FontWeight.w700,
                        height: 20 / 14,
                        letterSpacing: 0,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    TextSpan(
                      text: a.sentiment,
                      style: GoogleFonts.dmSans(
                        fontSize: isTablet ? 17 : (isSmallPhone ? 14 : 15.5),
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
                        fontSize: isTablet ? 17 : (isSmallPhone ? 14 : 15.5),
                        fontWeight: FontWeight.w700,
                        height: 20 / 14,
                        letterSpacing: 0,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    TextSpan(
                      text: a.impact,
                      style: GoogleFonts.dmSans(
                        fontSize: isTablet ? 17 : (isSmallPhone ? 14 : 15.5),
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
                    fontSize: isTablet ? 12 : (isSmallPhone ? 10 : 11),
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF8A8A8A),
                  ),
                ),
                Row(
                  children: [
                    if (a.companies.isNotEmpty ||
                        a.sector_market.isNotEmpty ||
                        a.commodities_market.isNotEmpty)
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Image.asset(
                          "assets/tradingview.png",
                          height: isTablet ? 34 : (isSmallPhone ? 24 : 28),
                          width: isTablet ? 34 : (isSmallPhone ? 24 : 28),
                        ),
                        onPressed: () async {
                          try {
                            if (a.companies.isNotEmpty) {
                              final companies = await _fetchCompanyDetails(a.companies);
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
                              final sector = await _fetchSectorDetails(a.sector_market);
                              if (sector != null) {
                                _openTradingView("NSE:${sector["symbol"]}");
                              }
                              return;
                            }
                            if (a.commodities_market.isNotEmpty) {
                              final List<Map<String, dynamic>> commodityList = [];
                              for (String name in a.commodities_market) {
                                final data = await _fetchCommodityDetails(name);
                                if (data != null) {
                                  commodityList.add(data);
                                }
                              }
                              if (commodityList.isEmpty) return;
                              if (commodityList.length == 1) {
                                _openTradingView(commodityList.first["symbol"].toString());
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
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        _locallySavedIds.contains(a.id)
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        size: isTablet ? 34 : (isSmallPhone ? 24 : 28),
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

  Widget _buildTodayEventsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE54350)),
      );
    }
    
    if (_todayEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              "No events for today",
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();
    final todayFormatted = DateFormat('dd MMM yyyy').format(now);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Today's Events",
                  style: GoogleFonts.dmSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF333333),
                  ),
                ),
                Text(
                  todayFormatted,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFE54350),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Event Cards
            ..._todayEvents.map((event) => _buildUnifiedEventCard(event)),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingEventsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE54350)),
      );
    }
    
    if (_upcomingEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              "No upcoming events",
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Upcoming Events",
              style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 20),

            ..._upcomingEvents.map((event) => _buildUnifiedEventCard(event)),
          ],
        ),
      ),
    );
  }

  // Unified Event Card Design for Both Today and Upcoming
  Widget _buildUnifiedEventCard(CorporateEvent event) {
    final dateFormatted = DateFormat('dd MMM yyyy').format(event.date);
    final timeFormatted = DateFormat('hh:mm a').format(event.date);
    final isExpanded = _expandedEventId == event.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_expandedEventId == event.id) {
            _expandedEventId = null;
          } else {
            _expandedEventId = event.id;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 16),
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
              // Left Red Accent Strip
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

              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and Bookmark Row
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
                              onTap: () => _toggleSaveEvent(event),
                              child: Icon(
                                _locallySavedEventIds.contains(event.id)
                                    ? Icons.bookmark
                                    : Icons.bookmark_border,
                                color: _locallySavedEventIds.contains(event.id)
                                    ? const Color(0xFFE54350)
                                    : const Color(0xFF94A3B8),
                                size: 24,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Description
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

                      // Date in Collapsed State
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

                      // Expanded Footer Section
                      if (isExpanded) ...[
                        const SizedBox(height: 8),
                        Container(
                          height: 1,
                          color: const Color(0xFFE2E8F0),
                        ),
                        const SizedBox(height: 16),

                        // Time Row
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

                        // Date Row
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
                        const SizedBox(height: 16),

                        // Remind Me Button
                        Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: 122,
                            height: 44,
                            child: ElevatedButton(
                              onPressed: () => _toggleSaveEvent(event),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE54350),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              child: Text(
                                "Remind Me",
                                style: GoogleFonts.dmSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
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
}

Future<void> addEventToGoogleCalendar({
  required String title,
  required String description,
  required DateTime startTime,
  required DateTime endTime,
}) async {
  String formatDate(DateTime dt) {
    return DateFormat("yyyyMMdd'T'HHmmss").format(dt);
  }

  final start = formatDate(startTime);
  final end = formatDate(endTime);

  final url =
      "https://www.google.com/calendar/render?action=TEMPLATE"
      "&text=${Uri.encodeComponent(title)}"
      "&details=${Uri.encodeComponent(description)}"
      "&dates=$start/$end";

  final uri = Uri.parse(url);

  if (!await launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
  )) {
    throw 'Could not launch Google Calendar';
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

