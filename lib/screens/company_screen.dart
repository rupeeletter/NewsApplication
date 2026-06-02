import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'company_news_screen.dart';
import 'home_screen.dart';
import 'chatbot_screen.dart';
import 'events_screen.dart';
import 'saved_screen.dart';
import 'profile_screen.dart';
import '../services/stock_price_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'index_screen.dart';

class CompanyScreen extends StatefulWidget {
  const CompanyScreen({super.key});

  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _filteredCompanies = [];
  bool _isLoading = false;
  String _error = '';
  int _bottomIndex = 1;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applySearch);
    _fetchCompanies();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applySearch);
    _searchController.dispose();
    super.dispose();
  }

  void _applySearch() {
  final query = _searchController.text.trim().toLowerCase();

  setState(() {
    if (query.isEmpty) {
      _filteredCompanies = List.from(_companies);
    } else {
      _filteredCompanies = _companies.where((company) {
        final name = (company["Company Name"] ?? "").toLowerCase();
        final symbol = (company["Symbol"] ?? "").toLowerCase();

        return name.contains(query) || symbol.contains(query);
      }).toList();
    }
  });
}

  Future<void> _fetchCompanies() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final resp = await http.get(Uri.parse("http://51.20.136.45:5000/api/companies"));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        setState(() {
          _companies = (data as List).cast<Map<String, dynamic>>();
          _filteredCompanies = List.from(_companies);
        });
      } else {
        final errorBody = resp.body;
        setState(() {
          _error = "Failed to fetch companies from DB\nStatus: ${resp.statusCode}\nError: $errorBody";
        });
      }
    } catch (e) {
      setState(() {
        _error = "DB fetch failed: $e";
      });
    }

    setState(() => _isLoading = false);
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
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FA),
      appBar: AppBar(
        title: const Text("Companies"),
        backgroundColor: const Color(0xFFEA6B6B),
        foregroundColor: Colors.white,
        actions: [
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            child: const Padding(
              padding: EdgeInsets.only(right: 16),
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
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  child: Container(
    height: 50,
    decoration: BoxDecoration(
      color: const Color(0xFFF6B3B3),
      borderRadius: BorderRadius.circular(30),
    ),
    child: TextField(
      controller: _searchController,
      onChanged: (value) => _applySearch(),
      decoration: InputDecoration(
        hintText: "Search company or symbol...",
        hintStyle: const TextStyle(color: Colors.black54),
        prefixIcon: const Icon(Icons.search, color: Colors.black54),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  _searchController.clear();
                  _applySearch();
                },
              )
            : null,
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    ),
  ),
),    // Company List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error.isNotEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _error,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _fetchCompanies,
                                child: const Text("Retry"),
                              ),
                            ],
                          ),
                        )
                      : _filteredCompanies.isEmpty
                          ? const Center(child: Text("No companies found"))
                          : RefreshIndicator(
                              onRefresh: _fetchCompanies,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                itemCount: _filteredCompanies.length,
                                itemBuilder: (context, index) {
                                  final company = _filteredCompanies[index];
                                  final companyName = company["Company Name"] ?? "Unknown";
                                  final symbol = company["Symbol"] ?? "";

                                  return CompanyListItem(
                                    companyName: companyName,
                                    symbol: symbol,
                                  );
                                },
                              ),
                            ),
            ),
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

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => destination!),
          );
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left side - Company info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.companyName,
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 25.6 / 16,
                        letterSpacing: 0,
                        color: const Color(0xFF191C1E),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.symbol.toUpperCase(),
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 21 / 14,
                        letterSpacing: -0.7,
                        color: const Color(0xFF5A5D72),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right side - Price info
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (stockData != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      stockData!['price'],
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 25.6 / 16,
                        color: const Color(0xFF191C1E),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPercentageBackgroundColor(stockData!['changePercent']),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${double.parse(stockData!['changePercent']) >= 0 ? '+' : ''}${stockData!['changePercent']}%',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _getPercentageTextColor(stockData!['changePercent']),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getPercentageBackgroundColor(String changePercent) {
    final value = double.parse(changePercent);
    if (value >= 0) {
      return const Color(0xFFE8F5E9); // Light green
    } else {
      return const Color(0xFFFFEBEE); // Light red/pink
    }
  }

  Color _getPercentageTextColor(String changePercent) {
    final value = double.parse(changePercent);
    if (value >= 0) {
      return const Color(0xFF2E7D32); // Dark green
    } else {
      return const Color(0xFFC62828); // Dark red
    }
  }
}
