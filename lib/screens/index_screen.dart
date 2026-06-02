import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:news_application/screens/saved_screen.dart';
import 'chatbot_screen.dart';
import 'company_news_screen.dart';
import 'events_screen.dart';
import 'home_screen.dart';
import '../models/article.dart';
import 'package:intl/intl.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/stock_price_service.dart';
import 'profile_screen.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';



class IndexScreen extends StatefulWidget {
  const IndexScreen({super.key});

  @override
  State<IndexScreen> createState() => _IndexScreenState();
}

class _IndexScreenState extends State<IndexScreen> {


  String selectedIndex = "^NSEI";
  int _bottomIndex = 1;
  int _tabIndex = 0;

  double price = 0;
  List chartData = [];
List gainers = [];
List losers = [];
  List news = [];
  List globalData = [];
  List sectorData = [];
  bool isGlobal = false;
  bool isSector = false;
Set<String> _locallySavedIds = {};
late String currentUserId;

  final String baseUrl = "http://51.20.136.45:5000";
  
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _filteredCompanies = [];
  Map<String, Map<String, dynamic>> _stockPriceCache = {};
  final TextEditingController _searchController = TextEditingController();
  bool _isLoadingCompanies = false;
  // InterstitialAd? _interstitialAd;
  // bool _isShowingAd = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyCompanySearch);
    // _loadInterstitialAd();
    _init();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    // _interstitialAd?.dispose();
    super.dispose();
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
  
  Future<void> _init() async {
    // Run in parallel instead of sequential
    await Future.wait([
      _loadUserId(),
      _fetchCompanies(),
    ]);
    
    // Only load saved IDs and fetch data after userId is ready
    await _loadSavedNewsIds();
    fetchIndexData();
  }
  
  void _applyCompanySearch() {
  final query = _searchController.text.trim().toLowerCase();

  if (query.isEmpty) {
    setState(() => _filteredCompanies = List.from(_companies));
    return;
  }

  setState(() {
    _filteredCompanies = _companies.where((company) {

      final companyName =
          company["Company Name"]?.toString().toLowerCase() ?? "";

      final symbol =
          company["Symbol"]?.toString().toLowerCase() ?? "";

      return companyName.contains(query) || symbol.contains(query);
    }).toList();
  });
}
  Future<void> _fetchCompanies() async {
    setState(() => _isLoadingCompanies = true);
    try {
      List<Map<String, dynamic>> allCompanies = [];
      int page = 1;
      bool hasMore = true;
      
      debugPrint("🔍 Fetching all companies...");
      
      // Fetch companies with pagination
      while (hasMore && page <= 20) {
        final url = page == 1 
            ? "$baseUrl/api/companies"
            : "$baseUrl/api/companies?page=$page&limit=100";
        
        final resp = await http.get(Uri.parse(url));
        debugPrint("📄 Page $page - Status: ${resp.statusCode}");
        
        if (resp.statusCode == 200) {
          final data = json.decode(resp.body);
          
          List<Map<String, dynamic>> pageCompanies;
          if (data is List) {
            pageCompanies = (data as List).cast<Map<String, dynamic>>();
          } else if (data is Map) {
            if (data.containsKey('data')) {
              pageCompanies = (data['data'] as List).cast<Map<String, dynamic>>();
            } else if (data.containsKey('companies')) {
              pageCompanies = (data['companies'] as List).cast<Map<String, dynamic>>();
            } else {
              pageCompanies = [];
            }
          } else {
            pageCompanies = [];
          }
          
          if (pageCompanies.isEmpty) {
            hasMore = false;
            debugPrint("✅ No more companies at page $page");
          } else {
            allCompanies.addAll(pageCompanies);
            debugPrint("📊 Page $page: ${pageCompanies.length} companies. Total: ${allCompanies.length}");
            
            // If we got less than 50, probably no more pages
            if (pageCompanies.length < 50) {
              hasMore = false;
            }
            page++;
          }
        } else {
          hasMore = false;
          debugPrint("⚠️ Failed at page $page");
        }
      }
      
      debugPrint("🎉 TOTAL COMPANIES LOADED: ${allCompanies.length}");
      if (allCompanies.isNotEmpty) {
        debugPrint("First: ${allCompanies.first['Company Name']}");
        debugPrint("Last: ${allCompanies.last['Company Name']}");
      }
      
      setState(() {
        _companies = allCompanies;
        _filteredCompanies = List.from(_companies);
      });
    } catch (e) {
      debugPrint("❌ Company fetch failed: $e");
    }
    setState(() => _isLoadingCompanies = false);
  }

  Future<void> fetchIndexData() async {
    if (!mounted) return;
    
    setState(() => _isLoadingCompanies = true);
    
    final res = await http.post(
      Uri.parse("$baseUrl/api/index/data"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"symbol": selectedIndex}),
    );

print(res.body);
print("STATUS CODE: ${res.statusCode}");
print("RAW RESPONSE: ${res.body}");

if (res.statusCode != 200) {
  print("Backend error");
  setState(() => _isLoadingCompanies = false);
  return;
} 
    final data = jsonDecode(res.body);

    setState(() {
      price = (data["price"] ?? 0).toDouble();
      chartData = data["chart"] ?? [];
      gainers = data["gainers"] ?? [];
      losers = data["losers"] ?? [];
      news = data["news"] ?? [];
      _isLoadingCompanies = false;
    });
  }

  Future<void> fetchGlobalData() async {
  setState(() => _isLoadingCompanies = true);
  
  final res = await http.post(
    Uri.parse("$baseUrl/api/index/global"),
    headers: {"Content-Type": "application/json"},
  );

  if (!mounted) return;

  final data = jsonDecode(res.body);

  setState(() {
    globalData = data;
    _isLoadingCompanies = false;
  });
}

Future<void> fetchGlobalNews() async {
  final res = await http.get(
    Uri.parse("$baseUrl/api/global-news"),
  );

  if (res.statusCode != 200) {
    print("Failed to fetch global news");
    return;
  }

  final data = jsonDecode(res.body);

  setState(() {
    news = data["data"] ?? [];
  });
}

Future<void> fetchSectorData() async {
  setState(() => _isLoadingCompanies = true);
  
  final res = await http.post(
    Uri.parse("$baseUrl/api/index/sectors"),
    headers: {"Content-Type": "application/json"},
  );

  if (!mounted) return;

  final data = jsonDecode(res.body);

  setState(() {
    sectorData = data;
    _isLoadingCompanies = false;
  });
}

Future<void> fetchSectorNews() async {
  final res = await http.get(
    Uri.parse("$baseUrl/api/sector-news"),
  );

  if (res.statusCode != 200) {
    print("Failed to fetch sector news");
    return;
  }

  final data = jsonDecode(res.body);

  setState(() {
    news = data["data"] ?? [];
  });
}
Article _convertToArticle(Map<String, dynamic> n) {
  return Article(
    id: n["_id"]?.toString() ?? "",
    fileName: n["FileName"]?.toString() ?? "",
    title: n["Headline"]?.toString() ?? "",
    excerpt: n["summary"]?.toString() ?? "",
    summary: n["summary"]?.toString() ?? "",
    story: n["story"]?.toString() ?? "",
    sentiment: n["sentiment"]?.toString() ?? "",
    impact: n["impact"]?.toString() ?? "",

    tags: (n["tags"] ?? [])
        .map<String>((e) => e.toString())
        .toList(),

    url: n["link"]?.toString() ?? "",

    companies: (n["companies"] ?? [])
        .map<String>((e) => e.toString())
        .toList(),

    sector_market: n["sector_market"]?.toString() ?? "",

    commodities_market: (n["commodities_market"] ?? [])
        .map<String>((e) => e.toString())
        .toList(),

    date: DateTime.tryParse(n["PublishedAt"]?.toString() ?? "") 
          ?? DateTime.now(),
  );
}
Widget _buildArticleCard(Article a) {
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

  return InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: () => _showFullStory(a), // SAME AS HOME PAGE
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// TITLE
          Text(
            a.title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 12),

          /// SUMMARY
          Text(
            a.summary,
            style: GoogleFonts.poppins(
              fontSize: 15,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 12),

          /// MARKET TAG
          if (a.companies.isNotEmpty)
            Text(
              "Companies: ${a.companies.join(', ')}",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            )
          else if (a.sector_market.isNotEmpty)
            Text(
              "Sector: ${a.sector_market}",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            )
          else if (a.commodities_market.isNotEmpty)
            Text(
              "Commodity: ${a.commodities_market.join(', ')}",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),

          const SizedBox(height: 8),

          /// SENTIMENT
          if (a.sentiment.isNotEmpty)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: "Sentiment: ",
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: a.sentiment,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: sentimentColor(a.sentiment),
                    ),
                  ),
                ],
              ),
            ),

          /// IMPACT
          if (a.impact.isNotEmpty)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: "Impact: ",
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: a.impact,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: impactColor(a.impact),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 14),

          /// FOOTER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

              /// DATE
              Text(
                dateFormatted,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),

              /// ACTIONS
              Row(
  children: [

    /// TRADINGVIEW
    if (a.companies.isNotEmpty)
      IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Image.asset(
          "assets/tradingview.png",
          height: 32,
          width: 32,
        ),
        onPressed: () {
          _openTradingView("NSE:${a.companies.first}");
        },
      )
    else if (a.sector_market.isNotEmpty)
      IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Image.asset(
          "assets/tradingview.png",
          height: 32,
          width: 32,
        ),
        onPressed: () async {
          final sectorData = await _fetchSectorDetails(a.sector_market);
          if (sectorData != null) {
            _openTradingView("NSE:${sectorData["symbol"]}");
          }
        },
      )
    else if (a.commodities_market.isNotEmpty)
      IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Image.asset(
          "assets/tradingview.png",
          height: 32,
          width: 32,
        ),
        onPressed: () {
          _openTradingView("MCX:${a.commodities_market.first}");
        },
      ),

    /// SAVE
    IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      icon: Icon(
        _locallySavedIds.contains(a.id)
            ? Icons.bookmark
            : Icons.bookmark_border,
        size: 32,
        color: _locallySavedIds.contains(a.id)
            ? Colors.red
            : Colors.grey,
      ),
      onPressed: () => _toggleSaveNews(a),
    ),
  ],
)
            ],
          ),
        ],
      ),
    ),
  );
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

Future<void> _loadUserId() async {
  final prefs = await SharedPreferences.getInstance();
  currentUserId = prefs.getString("userId") ?? "";
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
        _locallySavedIds =
           saved.map((e) {
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
Future<Map<String, dynamic>?> _fetchSectorDetails(String sector) async {
  final url =
      "$baseUrl/api/sector-lookup/by-name?name=$sector";

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


List<FlSpot> getMiniSpots(List chart) {
  List<FlSpot> spots = [];

  for (int i = 0; i < chart.length; i++) {
    final close = chart[i]["close"];
    if (close == null) continue;

    spots.add(
      FlSpot(spots.length.toDouble(), close.toDouble()),
    );
  }

  return spots;
}

List<FlSpot> getSpots() {
  List<FlSpot> spots = [];

  for (int i = 0; i < chartData.length; i++) {
    final close = chartData[i]["close"];

    if (close == null) continue;

    spots.add(
      FlSpot(
        spots.length.toDouble(),
        double.tryParse(close.toString()) ?? 0,
      ),
    );
  }

  return spots;
}
double _textWidth(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: Directionality.of(context),
  )..layout();

  return painter.size.width;
}

 Widget tab(String title, String symbol, int index) {
  bool active = _tabIndex == index;

  return GestureDetector(
    onTap: () {
      setState(() {
        _tabIndex = index;

        if (index == 4) {
          // Companies tab - clear index data
          isGlobal = false;
          isSector = false;
          chartData = [];
          gainers = [];
          losers = [];
          news = [];
          // Don't reset filtered companies, keep existing data
          if (_companies.isEmpty) {
            _fetchCompanies();
          }
        } else {
          // Clear old data immediately before fetching new data
          chartData = [];
          gainers = [];
          losers = [];
          news = [];
          price = 0;
          
          selectedIndex = symbol;
          isGlobal = (symbol == "^DJI");
          isSector = (index == 2);

          if (isGlobal) {
            globalData = [];
            fetchGlobalData();
            fetchGlobalNews();
          } else if (isSector) {
            sectorData = [];
            fetchSectorData();
            fetchSectorNews();
          } else {
            fetchIndexData();
          }
        }
      });
    },
    child: Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// TAB TEXT
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight:
                  active ? FontWeight.w600 : FontWeight.w400,
              color: active
                  ? const Color(0xFFEA6B6B)
                  : Colors.black54,
            ),
          ),

          const SizedBox(height: 4),

          /// UNDERLINE
          Container(
            height: 2,
            width: _textWidth(
              title,
              GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            color: active
                ? const Color(0xFFEA6B6B)
                : Colors.transparent,
          ),
          const Divider(height: 1, thickness: 0.8),
        ],
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
      height: 22,
    ),
    label: label,
    tooltip: label,
  );
}

@override
Widget build(BuildContext context) {
  final List displayGainers = gainers;
  final List displayLosers = losers;

  return Scaffold(
  backgroundColor: Colors.grey.shade100,

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
    body: SafeArea(
      child: ListView(
        children: [

          /// TOP BAR WITH SEARCH AND PROFILE
          Padding(
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                  child: const CircleAvatar(
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
          ),

          /// TABS
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                tab("NIFTY", "^NSEI", 0),
                const SizedBox(width: 8),
                tab("BANK NIFTY", "^NSEBANK", 1),
                const SizedBox(width: 8),
                tab("SECTORS", "^CNXIT", 2),
                const SizedBox(width: 8),
                tab("GLOBAL", "^DJI", 3),
                const SizedBox(width: 8),
                tab("COMPANIES", "", 4),
              ],
            ),
          ),

          const SizedBox(height: 10),

          /// COMPANIES TAB
          if (_tabIndex == 4)
  Padding(
    padding: const EdgeInsets.all(12),
    child: Column(
      children: [

        /// 🔍 SEARCH BAR
        Container(
          height: 45,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            borderRadius: BorderRadius.circular(25),
          ),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: "Search company...",
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: Colors.red),
            ),
          ),
        ),

        /// COMPANY LIST
        if (_companies.isEmpty && _isLoadingCompanies)
          const Center(child: CircularProgressIndicator())
        else if (_searchController.text.isEmpty && _companies.isEmpty)
          const Center(child: Text("No companies found"))
        else if (_searchController.text.isNotEmpty && _filteredCompanies.isEmpty)
          const Center(child: Text("No companies match your search"))
        else
          ...(_searchController.text.isEmpty ? _companies : _filteredCompanies).map((company) {
            final companyName = company["Company Name"]?.toString() ?? "Unknown";
            final symbol = company["Symbol"]?.toString() ?? "";

            return CompanyListItem(
              companyName: companyName,
              symbol: symbol,
            );
          }).toList(),
      ],
    ),
  )
          else if (isGlobal || isSector)
            ListView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  padding: const EdgeInsets.symmetric(horizontal: 16),
  itemCount: isGlobal ? globalData.length : sectorData.length,
  itemBuilder: (_, i) {

    final g = isGlobal ? globalData[i] : sectorData[i];
    final chartSpots = getMiniSpots(g["chart"]);
    final price = (g["price"] ?? 0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER - NAME AND BOOKMARK
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                g["name"] ?? "",
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.bookmark_border,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          /// PRICE
          Text(
            "₹${price.toStringAsFixed(2)}",
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          /// MINI CHART
          SizedBox(
            height: 100,
            child: chartSpots.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      minY: chartSpots.isEmpty ? 0 : chartSpots.map((e) => e.y).reduce((a, b) => a < b ? a : b) - 20,
                      maxY: chartSpots.isEmpty ? 100 : chartSpots.map((e) => e.y).reduce((a, b) => a > b ? a : b) + 20,
                      lineBarsData: [
                        LineChartBarData(
                          spots: chartSpots,
                          isCurved: true,
                          barWidth: 2.5,
                          color: const Color(0xFF4DD0E1),
                          dotData: FlDotData(show: false),
                          belowBarData: BarAreaData(show: false),
                        ),
                      ],
                    ),
                  ),
          ),

          const SizedBox(height: 8),

          /// TIME LABELS
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "6:15 AM",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                "10:30 PM",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                "3:30 PM",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  },
),
          /// NORMAL INDEX UI (ONLY FOR NIFTY AND BANK NIFTY)
          if (!isGlobal && !isSector && _tabIndex != 4) ...[

  /// INDEX PRICE CARD
  Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tabIndex == 0 ? "NIFTY" : "BANK NIFTY",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "₹${price.toStringAsFixed(2)}",
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "+52.00",
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.bookmark_border,
            size: 22,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    ),
  ),

  /// CHART CARD
  Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(16),
    height: 250,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.only(right: 10),
      child: chartData.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : LineChart(
              LineChartData(

    /// remove grid
    gridData: FlGridData(show: false),

    /// remove border
    borderData: FlBorderData(show: false),

    /// enable smooth touch
    lineTouchData: LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        tooltipBgColor: Colors.black,
      ),
    ),
    extraLinesData: ExtraLinesData(
      horizontalLines: [
        HorizontalLine(
          y: price,
          color: Colors.green.withOpacity(0.4),
          strokeWidth: 1,
          dashArray: [5,5],
        )
      ],
    ),

    /// axis titles
    titlesData: FlTitlesData(

      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 50,
          interval: 500,
          getTitlesWidget: (value, meta) {
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                value.toStringAsFixed(0),
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            );
          },
        ),
      ),

      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: 1,
          getTitlesWidget: (value, meta) {
            int index = value.toInt();
            if (index < 0 || index >= chartData.length) {
              return const SizedBox();
            }
            final date = DateTime.parse(chartData[index]["date"]);
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Transform.rotate(
                angle: -0.75,
                child: Text(
                  DateFormat("d MMM").format(date),
                  style: const TextStyle(
                    fontSize: 8,
                    color: Colors.grey,
                  ),
                ),
              ),
            );
          },
        ),
      ),

      topTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),

      rightTitles: AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
    ),

    /// IMPORTANT for proper scaling
    minY: getSpots().map((e) => e.y).reduce((a,b)=>a<b?a:b) - 20,
    maxY: getSpots().map((e) => e.y).reduce((a,b)=>a>b?a:b) + 20,

    lineBarsData: [
      LineChartBarData(
        spots: getSpots(),

        /// smooth curve
        isCurved: false,

        /// line thickness
        barWidth: 3,

        /// green color
        color: Colors.green,

        /// show dot data points at every date
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            return FlDotCirclePainter(
              radius: 3,
              color: Colors.green,
              strokeWidth: 1.5,
              strokeColor: Colors.white,
            );
          },
        ),

        /// gradient area under chart
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [
              Colors.green.withOpacity(0.4),
              Colors.green.withOpacity(0.05),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    ],
  ),
)
              )
            ),

           /// SHOW TOP GAINERS/LOSERS ONLY FOR NIFTY TAB (NOT BANK NIFTY)
if (_tabIndex == 0) ...[
  
  const SizedBox(height: 16),
  
  /// TOP GAINERS SECTION
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Text(
      "Top Gainers",
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),

  const SizedBox(height: 12),

  Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayGainers.length,
          itemBuilder: (_, i) {
            final m = displayGainers[i];
            final change = (m["pChange"] ?? 0).toDouble();

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: i < displayGainers.length - 1
                      ? BorderSide(color: Colors.grey.shade200)
                      : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m["symbol"] ?? "",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "₹${m["lastPrice"]}",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "+${change.toStringAsFixed(2)}%",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    ),
  ),

  const SizedBox(height: 16),

  /// TOP LOSERS SECTION
  Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Text(
      "Top Losers",
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),

  const SizedBox(height: 12),

  Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: displayLosers.length,
          itemBuilder: (_, i) {
            final m = displayLosers[i];
            final change = (m["pChange"] ?? 0).toDouble();

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: i < displayLosers.length - 1
                      ? BorderSide(color: Colors.grey.shade200)
                      : BorderSide.none,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m["symbol"] ?? "",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "₹${m["lastPrice"]}",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "${change.toStringAsFixed(2)}%",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    ),
  ),
],

           
          ],

          /// NEWS (ONLY FOR INDEX TABS, NOT COMPANIES, GLOBAL, OR SECTORS)
          if (_tabIndex != 4 && !isGlobal && !isSector) ...[
            const SizedBox(height: 10),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                "NEWS",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: news.length,
              itemBuilder: (_, i) {
                final article = _convertToArticle(news[i]);
                return _buildArticleCard(article);
              },
            ),
          ],
          
          /// NEWS FOR GLOBAL AND SECTORS
          if ((isGlobal || isSector) && news.isNotEmpty) ...[
            const SizedBox(height: 10),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                "NEWS",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ),

            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: news.length,
              itemBuilder: (_, i) {
                final article = _convertToArticle(news[i]);
                return _buildArticleCard(article);
              },
            ),
          ],

          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}
}

class OptimizedCompanyListItem extends StatelessWidget {
  final String companyName;
  final String symbol;
  final Map<String, dynamic>? stockData;

  const OptimizedCompanyListItem({
    super.key,
    required this.companyName,
    required this.symbol,
    this.stockData,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 4),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CompanyNewsScreen(
                companyName: companyName,
                companySymbol: symbol,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade200, width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  companyName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (stockData == null)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                const SizedBox(
                  height: 30,
                  child: VerticalDivider(color: Colors.grey, thickness: 1),
                ),
                const SizedBox(width: 8),
                Text(
  stockData!['price'].toString(),

                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
  '${stockData!['changePercent'].toString()}%',

                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: double.parse(stockData!['changePercent'].toString()) >= 0
    ? Colors.green
    : Colors.red,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CompanyListItem extends StatefulWidget {
  final String companyName;
  final String symbol;

  const CompanyListItem({
    super.key,
    required this.companyName,
    required this.symbol,
  });

  @override
  State<CompanyListItem> createState() => _CompanyListItemState();
}

class _CompanyListItemState extends State<CompanyListItem> {
  Map<String, dynamic>? stockData;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStockPrice();
  }

  Future<void> _fetchStockPrice() async {
    if (widget.symbol.isEmpty) {
      setState(() => loading = false);
      return;
    }

    final data = await StockPriceService.getStockPrice(widget.symbol);
    setState(() {
      stockData = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CompanyNewsScreen(
                companyName: widget.companyName,
                companySymbol: widget.symbol,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.companyName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.symbol,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (stockData != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${stockData!['price'].toString()}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: double.parse(stockData!['changePercent'].toString()) >= 0
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${double.parse(stockData!['changePercent'].toString()) >= 0 ? '+' : ''}${stockData!['changePercent'].toString()}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: double.parse(stockData!['changePercent'].toString()) >= 0
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}