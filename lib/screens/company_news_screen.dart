// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:intl/intl.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
// import 'package:webview_flutter/webview_flutter.dart';
// import 'home_screen.dart';
// import 'chatbot_screen.dart';
// import 'company_screen.dart';
// import 'events_screen.dart';
// import 'saved_screen.dart';
// import 'profile_screen.dart';
// import 'package:flutter_svg/flutter_svg.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'index_screen.dart';

// class CompanyNewsScreen extends StatefulWidget {
//   final String companyName;
//   final String companySymbol;

//   const CompanyNewsScreen({
//     super.key,
//     required this.companyName,
//     required this.companySymbol,
//   });

//   @override
//   State<CompanyNewsScreen> createState() => _CompanyNewsScreenState();
// }

// class _CompanyNewsScreenState extends State<CompanyNewsScreen> with SingleTickerProviderStateMixin {
//   List<Map<String, dynamic>> _news = [];
//   Map<String, dynamic>? _stockData;
//   Map<String, dynamic>? _aiOverview;
//   Map<String, dynamic>? _aiInsight;
//   List<Map<String, dynamic>> _companyEvents = [];
//   bool _isLoading = false;
//   bool _isLoadingStock = false;
//   bool _isLoadingAI = false;
//   bool _isLoadingInsight = false;
//   bool _isLoadingEvents = false;
//   String _error = '';
//   String _stockError = '';
//   String _aiError = '';
//   String _insightError = '';
//   String _eventsError = '';
  
//   late TabController _tabController;
//   int _selectedTabIndex = 0;
//   int _bottomIndex = 1;

//   List<Map<String, dynamic>> _chartData = [];
//   bool _isLoadingChart = false;
//   String _chartError = '';
//   String _selectedTimeframe = '1M';
//   WebViewController? _webViewController;
//   bool _chartInitialized = false;

//   final String _finedgeApiToken = dotenv.env['FINEDGE_API_TOKEN']!;
  
//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 4, vsync: this);
//     _tabController.addListener(() {
//       setState(() {
//         _selectedTabIndex = _tabController.index;
//       });
//     });
    
//     // Initialize WebViewController once
//     _webViewController = WebViewController()
//       ..setJavaScriptMode(JavaScriptMode.unrestricted)
//       ..setBackgroundColor(Colors.white)
//       ..setNavigationDelegate(
//         NavigationDelegate(
//           onPageFinished: (url) {
//             setState(() {
//               _chartInitialized = true;
//             });
//           },
//         ),
//       );
    
//     _fetchStockData();
//     _fetchCompanyNews();
//     _fetchAIOverview();
//     _fetchAIInsight();
//     _fetchChartData('1M');
//     _fetchCompanyEvents();
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }

//   Future<void> _fetchStockData() async {
//     setState(() {
//       _isLoadingStock = true;
//       _stockError = '';
//     });

//     try {
//       var symbol = widget.companySymbol.toUpperCase();
      
//       // Remove .NSE or .BSE suffix if present
//       if (symbol.endsWith('.NSE') || symbol.endsWith('.BSE')) {
//         symbol = symbol.split('.').first;
//       }
      
//       print('==========================================');
//       print('Fetching stock data for symbol: $symbol');
//       print('==========================================');
      
//       // Add retry logic with exponential backoff
//       int retries = 3;
//       int delayMs = 1000;
//       http.Response? quoteResponse;
      
//       for (int i = 0; i < retries; i++) {
//         try {
//           quoteResponse = await http.get(
//             Uri.parse("https://data.finedgeapi.com/api/v1/quote").replace(
//               queryParameters: {'symbol': symbol, 'token': _finedgeApiToken}
//             ),
//             headers: {'Accept': 'application/json'}
//           ).timeout(const Duration(seconds: 10));

//           print('Quote API Status: ${quoteResponse.statusCode}');
          
//           if (quoteResponse.statusCode == 200) {
//             break; // Success
//           } else if (quoteResponse.statusCode == 503 || quoteResponse.statusCode == 429) {
//             print('Rate limited. Retrying in ${delayMs}ms... (Attempt ${i + 1}/$retries)');
//             if (i < retries - 1) {
//               await Future.delayed(Duration(milliseconds: delayMs));
//               delayMs *= 2; // Exponential backoff
//             }
//           } else {
//             break; // Other error
//           }
//         } catch (e) {
//           if (i == retries - 1) rethrow;
//           print('Request failed: $e. Retrying...');
//           await Future.delayed(Duration(milliseconds: delayMs));
//           delayMs *= 2;
//         }
//       }

//       if (quoteResponse == null || quoteResponse.statusCode != 200) {
//         setState(() {
//           _stockError = quoteResponse?.statusCode == 503 || quoteResponse?.statusCode == 429
//               ? "Rate limit exceeded. Please wait and try again."
//               : "Failed to fetch quote data (${quoteResponse?.statusCode ?? 'timeout'})";
//         });
//         return;
//       }

//       print('Quote API Response: ${quoteResponse.body}');

//       final quoteJson = json.decode(quoteResponse.body);
      
//       dynamic quoteData;
//       if (quoteJson is Map) {
//         quoteData = quoteJson[symbol] ?? quoteJson[symbol.toLowerCase()] ?? 
//                    quoteJson['data'] ?? quoteJson;
//       } else {
//         quoteData = quoteJson;
//       }
      
//       if (quoteData == null || (quoteData is! Map && quoteData is! List)) {
//         setState(() {
//           _stockError = "Invalid data format for symbol: $symbol";
//         });
//         return;
//       }

//       if (quoteData is List && quoteData.isNotEmpty) {
//         quoteData = quoteData.first;
//       }

//       final currentPrice = quoteData['current_price'] ?? 
//                           quoteData['last_price'] ?? 
//                           quoteData['ltp'] ?? 
//                           quoteData['close'] ??
//                           quoteData['lastPrice'];
//       final high = quoteData['high_price'] ?? 
//                   quoteData['high'] ?? 
//                   quoteData['dayHigh'];
//       final low = quoteData['low_price'] ?? 
//                  quoteData['low'] ?? 
//                  quoteData['dayLow'];
//       final open = quoteData['open_price'] ?? 
//                   quoteData['open'] ?? 
//                   quoteData['openPrice'];
//       final changePercent = quoteData['change'] ?? 
//                            quoteData['pChange'] ?? 
//                            quoteData['percentChange'] ??
//                            quoteData['changePct'];
//       final volume = quoteData['volume'] ?? 
//                     quoteData['totalTradedVolume'];

//       double? changeValue;
//       double? changePct;
//       if (changePercent != null) {
//         try {
//           changePct = double.parse(changePercent.toString().replaceAll('%', '').trim());
//           if (currentPrice != null && open != null) {
//             changeValue = double.parse(currentPrice.toString()) - double.parse(open.toString());
//           }
//         } catch (e) {
//           print('Error parsing change percent: $e');
//         }
//       }

//       // 2. GET /annual-price-ratios - Add retry logic here too
//       String? eps;
//       String? peRatio;

//       try {
//         print('\n--- Fetching Price Ratios for EPS and P/E ---');
        
//         // Add delay before next API call
//         await Future.delayed(const Duration(milliseconds: 500));
        
//         final priceRatiosUrl = Uri.parse(
//           "https://data.finedgeapi.com/api/v1/annual-price-ratios/$symbol"
//         ).replace(queryParameters: {
//           'token': _finedgeApiToken,
//           'statement_type': 's',
//         });

//         final priceRatiosResponse = await http.get(
//           priceRatiosUrl,
//           headers: {'Accept': 'application/json'}
//         ).timeout(const Duration(seconds: 10));

//         print('Price Ratios Status: ${priceRatiosResponse.statusCode}');
        
//         if (priceRatiosResponse.statusCode == 200 && priceRatiosResponse.body.isNotEmpty) {
//           final ratiosData = json.decode(priceRatiosResponse.body);
//           print('Full Ratios Response: $ratiosData');
          
//           // Extract from price_ratios array
//           dynamic ratiosList = ratiosData['price_ratios'];
//           print('Extracted ratiosList: $ratiosList');
          
//           if (ratiosList != null && ratiosList is List && ratiosList.isNotEmpty) {
//             final latest = ratiosList.first;
//             print('Latest ratio entry keys: ${latest.keys.toList()}');
//             print('Latest ratio entry: $latest');
            
//             // Extract P/E Ratio
//             final peValue = latest['pe'] ?? 
//                            latest['priceToEarnings'] ?? 
//                            latest['PE'] ??
//                            latest['peRatio'] ??
//                            latest['priceEarningsRatio'];
//             if (peValue != null) {
//               peRatio = double.parse(peValue.toString()).toStringAsFixed(2);
//               print('✓ Found P/E: $peRatio');
//             } else {
//               print('✗ P/E not found in: ${latest.keys.toList()}');
//             }
//           } else {
//             print('✗ No ratios list found or empty');
//           }
//         }
//       } catch (e) {
//         print('ERROR fetching price ratios: $e');
//       }

//       // 3. GET /financials - Add retry logic here too
//       String? revenue;
//       String? ebitda;
//       String? ebit;
//       String? netProfit;

//       try {
//         print('\n--- Fetching Financials ---');
        
//         // Add delay before next API call
//         await Future.delayed(const Duration(milliseconds: 500));
        
//         final financialsUrl = Uri.parse(
//           "https://data.finedgeapi.com/api/v1/financials/$symbol"
//         ).replace(queryParameters: {
//           'token': _finedgeApiToken,
//           'statement_type': 's',
//           'statement_code': 'pl',
//           'period': 'annual',
//         });

//         final financialsResponse = await http.get(
//           financialsUrl,
//           headers: {'Accept': 'application/json'}
//         ).timeout(const Duration(seconds: 10));

//         print('Financials Status: ${financialsResponse.statusCode}');

//         if (financialsResponse.statusCode == 200 && financialsResponse.body.isNotEmpty) {
//           final finData = json.decode(financialsResponse.body);
//           print('Financials Data Type: ${finData.runtimeType}');
          
//           dynamic financialsList;
//           if (finData is Map) {
//             financialsList = finData['financials'] ?? finData['data'] ?? finData['results'];
//             print('Extracted financialsList: ${financialsList?.runtimeType}');
//           } else if (finData is List) {
//             financialsList = finData;
//           }
          
//           if (financialsList != null && financialsList is List && financialsList.isNotEmpty) {
//             final latest = financialsList.first;
//             print('Latest financial entry keys: ${latest.keys.toList()}');
//             print('Latest financial entry values sample: ${latest.entries.take(5).toList()}');
            
//             // Improved bank detection: Check for MULTIPLE bank-specific indicators
//             // Regular companies may have 'income' field but won't have bank-specific fields
//             final isBank = (latest.containsKey('interestEarned') && 
//                            latest.containsKey('interestExpended')) ||
//                           (latest.containsKey('netInterestIncome')) ||
//                           (latest.containsKey('income') && 
//                            !latest.containsKey('revenueFromOperations') &&
//                            !latest.containsKey('costofGoodsSold'));
            
//             if (isBank) {
//               print('Detected: BANK/FINANCIAL INSTITUTION');
              
//               // For banks: Revenue = Total Income
//               final totalIncome = latest['income'] ?? 
//                                  latest['totalIncome'] ??
//                                  latest['operatingIncome'];
//               if (totalIncome != null) {
//                 final revValue = double.parse(totalIncome.toString()) / 10000000;
//                 revenue = revValue.toStringAsFixed(2);
//                 print('✓ Found Total Income (Revenue): $revenue Cr');
//               }
              
//               // For banks: Net Profit
//               final netIncome = latest['profitLossForThePeriod'] ??
//                                latest['profitLossForPeriod'] ??
//                                latest['netProfit'] ??
//                                latest['profitAfterTax'];
//               if (netIncome != null) {
//                 final npValue = double.parse(netIncome.toString()) / 10000000;
//                 netProfit = npValue.toStringAsFixed(2);
//                 print('✓ Found Net Profit: $netProfit Cr');
//               }
              
//               // For banks: Operating Profit can be used as EBIT equivalent
//               final operatingProfit = latest['profitLossBeforeTax'] ??
//                                      latest['profitBeforeTax'];
//               if (operatingProfit != null) {
//                 final ebitValue = double.parse(operatingProfit.toString()) / 10000000;
//                 ebit = ebitValue.toStringAsFixed(2);
//                 print('✓ Found Operating Profit (EBIT): $ebit Cr');
//               }
              
//               // EBITDA not typically applicable for banks
//               ebitda = 'N/A (Bank)';
              
//             } else {
//               print('Detected: REGULAR COMPANY');
              
//               // Extract Revenue (for regular companies)
//               final totalRev = latest['revenueFromOperations'] ?? 
//                               latest['totalRevenue'] ?? 
//                               latest['revenue'] ?? 
//                               latest['operatingRevenue'] ??
//                               latest['netRevenue'] ??
//                               latest['Revenue'] ??
//                               latest['totalIncome'];
//               if (totalRev != null) {
//                 final revValue = double.parse(totalRev.toString()) / 10000000;
//                 revenue = revValue.toStringAsFixed(2);
//                 print('✓ Found Revenue: $revenue Cr');
//               } else {
//                 print('✗ Revenue not found. Available keys: ${latest.keys.toList()}');
//               }
              
//               // Extract Net Profit
//               final netIncome = latest['profitLossForPeriod'] ??
//                                latest['profitLossForThePeriod'] ??
//                                latest['netIncome'] ?? 
//                                latest['netProfit'] ??
//                                latest['profitAfterTax'] ??
//                                latest['Net Profit'] ??
//                                latest['netIncomeAfterTax'];
//               if (netIncome != null) {
//                 final npValue = double.parse(netIncome.toString()) / 10000000;
//                 netProfit = npValue.toStringAsFixed(2);
//                 print('✓ Found Net Profit: $netProfit Cr');
//               } else {
//                 print('✗ Net Profit not found');
//               }
              
//               // Calculate EBITDA
//               try {
//                 final pbt = latest['profitBeforeTax'];
//                 final finCosts = latest['financeCosts'];
//                 final depreciation = latest['depreciationAndAmortisation'];
                
//                 if (pbt != null && finCosts != null && depreciation != null) {
//                   final ebitdaValue = (double.parse(pbt.toString()) + 
//                                       double.parse(finCosts.toString()) + 
//                                       double.parse(depreciation.toString())) / 10000000;
//                   ebitda = ebitdaValue.toStringAsFixed(2);
//                   print('✓ Calculated EBITDA: $ebitda Cr');
//                 }
//               } catch (e) {
//                 print('Could not calculate EBITDA: $e');
//               }
              
//               // Calculate EBIT
//               try {
//                 final pbt = latest['profitBeforeTax'];
//                 final finCosts = latest['financeCosts'];
                
//                 if (pbt != null && finCosts != null) {
//                   final ebitValue = (double.parse(pbt.toString()) + 
//                                     double.parse(finCosts.toString())) / 10000000;
//                   ebit = ebitValue.toStringAsFixed(2);
//                   print('✓ Calculated EBIT: $ebit Cr');
//                 }
//               } catch (e) {
//                 print('Could not calculate EBIT: $e');
//               }
//             }
            
//             // Extract EPS (common for both)
//             final epsValue = latest['eps'] ?? 
//                             latest['earningsPerShare'] ?? 
//                             latest['EPS'] ??
//                             latest['basicEPS'];
//             if (epsValue != null) {
//               eps = double.parse(epsValue.toString()).toStringAsFixed(2);
//               print('✓ Found EPS: $eps');
//             } else {
//               print('✗ EPS not found');
//             }
//           } else {
//             print('✗ No financials list found or empty');
//           }
//         }
//       } catch (e, stack) {
//         print('ERROR fetching financials: $e');
//         print('Stack: $stack');
//       }

//       // 4. GET /basic-financials - Balance Sheet
//       String? totalAssets;
//       String? totalLiabilities;
//       String? longTermDebt;
//       String? shareholdersEquity;
//       String? cashEquivalents;

//       try {
//         print('\n--- Fetching Balance Sheet ---');
//         await Future.delayed(const Duration(milliseconds: 500));
        
//         final bsUrl = Uri.parse(
//           "https://data.finedgeapi.com/api/v1/basic-financials/$symbol"
//         ).replace(queryParameters: {
//           'token': _finedgeApiToken,
//           'statement_type': 's',
//           'statement_code': 'bs',
//         });

//         final bsResponse = await http.get(
//           bsUrl,
//           headers: {'Accept': 'application/json'}
//         ).timeout(const Duration(seconds: 10));

//         print('Balance Sheet Status: ${bsResponse.statusCode}');

//         if (bsResponse.statusCode == 200 && bsResponse.body.isNotEmpty) {
//           final bsData = json.decode(bsResponse.body);
          
//           dynamic bsList = bsData['ratios'];
          
//           if (bsList != null && bsList is List && bsList.isNotEmpty) {
//             final latest = bsList.first;
//             print('Balance Sheet keys: ${latest.keys.toList()}');
            
//             // Total Assets
//             final assets = latest['totalAssets'];
//             if (assets != null) {
//               totalAssets = (double.parse(assets.toString()) / 10000000).toStringAsFixed(2);
//               print('✓ Found Total Assets: $totalAssets Cr');
//             }
            
//             // Total Liabilities
//             final liabilities = latest['totalLiabilities'];
//             if (liabilities != null) {
//               totalLiabilities = (double.parse(liabilities.toString()) / 10000000).toStringAsFixed(2);
//               print('✓ Found Total Liabilities: $totalLiabilities Cr');
//             }
            
//             // Long-term Debt
//             final debt = latest['longTermBorrowings'] ?? latest['totalDebt'];
//             if (debt != null) {
//               longTermDebt = (double.parse(debt.toString()) / 10000000).toStringAsFixed(2);
//               print('✓ Found Long-Term Debt: $longTermDebt Cr');
//             }
            
//             // Shareholders' Equity
//             final equity = latest['totalEquity'];
//             if (equity != null) {
//               shareholdersEquity = (double.parse(equity.toString()) / 10000000).toStringAsFixed(2);
//               print('✓ Found Shareholders Equity: $shareholdersEquity Cr');
//             }
            
//             // Cash & Equivalents
//             final cash = latest['totalCash'];
//             if (cash != null) {
//               cashEquivalents = (double.parse(cash.toString()) / 10000000).toStringAsFixed(2);
//               print('✓ Found Cash & Equivalents: $cashEquivalents Cr');
//             }
//           }
//         }
//       } catch (e) {
//         print('ERROR fetching balance sheet: $e');
//       }

//       // 5. GET /basic-financials - Cash Flow
//       String? operatingCashFlow;
//       String? investingCashFlow;
//       String? financingCashFlow;

//       try {
//         print('\n--- Fetching Cash Flow ---');
//         await Future.delayed(const Duration(milliseconds: 500));
        
//         final cfUrl = Uri.parse(
//           "https://data.finedgeapi.com/api/v1/basic-financials/$symbol"
//         ).replace(queryParameters: {
//           'token': _finedgeApiToken,
//           'statement_type': 's',
//           'statement_code': 'cf',
//         });

//         final cfResponse = await http.get(
//           cfUrl,
//           headers: {'Accept': 'application/json'}
//         ).timeout(const Duration(seconds: 10));

//         print('Cash Flow Status: ${cfResponse.statusCode}');

//         if (cfResponse.statusCode == 200 && cfResponse.body.isNotEmpty) {
//           final cfData = json.decode(cfResponse.body);
          
//           dynamic cfList = cfData['ratios'];
          
//           if (cfList != null && cfList is List && cfList.isNotEmpty) {
//             final latest = cfList.first;
//             print('Cash Flow keys: ${latest.keys.toList()}');
            
//             // Operating Cash Flow
//             final opCF = latest['operatingCashFlow'];
//             if (opCF != null) {
//               operatingCashFlow = (double.parse(opCF.toString()) / 10000000).toStringAsFixed(2);
//               print('✓ Found Operating Cash Flow: $operatingCashFlow Cr');
//             }
            
//             // Investing Cash Flow
//             final invCF = latest['investingCashFlow'];
//             if (invCF != null) {
//               investingCashFlow = (double.parse(invCF.toString()) / 10000000).toStringAsFixed(2);
//               print('✓ Found Investing Cash Flow: $investingCashFlow Cr');
//             }
            
//             // Financing Cash Flow
//             final finCF = latest['financingCashFlow'];
//             if (finCF != null) {
//               financingCashFlow = (double.parse(finCF.toString()) / 10000000).toStringAsFixed(2);
//               print('✓ Found Financing Cash Flow: $financingCashFlow Cr');
//             }
//           }
//         }
//       } catch (e) {
//         print('ERROR fetching cash flow: $e');
//       }

//       // 6. Fetch additional ratios (P/B, P/S, Market Cap)
//       String? pbRatio;
//       String? psRatio;
//       String? marketCap;

//       try {
//         print('\n--- Fetching Additional Ratios ---');
//         await Future.delayed(const Duration(milliseconds: 500));
        
//         final ratiosUrl = Uri.parse(
//           "https://data.finedgeapi.com/api/v1/annual-price-ratios/$symbol"
//         ).replace(queryParameters: {
//           'token': _finedgeApiToken,
//           'statement_type': 's',
//         });

//         final ratiosResp = await http.get(
//           ratiosUrl,
//           headers: {'Accept': 'application/json'}
//         ).timeout(const Duration(seconds: 10));

//         if (ratiosResp.statusCode == 200 && ratiosResp.body.isNotEmpty) {
//           final ratiosData = json.decode(ratiosResp.body);
//           dynamic ratiosList = ratiosData['price_ratios'];
          
//           if (ratiosList != null && ratiosList is List && ratiosList.isNotEmpty) {
//             final latest = ratiosList.first;
//             print('Ratios keys: ${latest.keys.toList()}');
            
//             // P/B Ratio
//             final pb = latest['pb'] ?? latest['priceToBook'] ?? latest['pbRatio'];
//             if (pb != null) {
//               pbRatio = double.parse(pb.toString()).toStringAsFixed(2);
//               print('✓ Found P/B: $pbRatio');
//             }
            
//             // P/S Ratio
//             final ps = latest['ps'] ?? latest['priceToSales'] ?? latest['psRatio'];
//             if (ps != null) {
//               psRatio = double.parse(ps.toString()).toStringAsFixed(2);
//               print('✓ Found P/S: $psRatio');
//             }
            
//             // Market Cap
//             final mktCap = latest['marketCap'] ?? latest['market_cap'];
//             if (mktCap != null) {
//               marketCap = (double.parse(mktCap.toString()) / 10000000).toStringAsFixed(2);
//               print('✓ Found Market Cap: $marketCap Cr');
//             }
//           }
//         }
//       } catch (e) {
//         print('ERROR fetching additional ratios: $e');
//       }

//       print('\n=== FINAL EXTRACTED VALUES ===');
//       print('Revenue: $revenue');
//       print('EBITDA: $ebitda');
//       print('EBIT: $ebit');
//       print('Net Profit: $netProfit');
//       print('EPS: $eps');
//       print('P/E Ratio: $peRatio');
//       print('Total Assets: $totalAssets');
//       print('Total Liabilities: $totalLiabilities');
//       print('Long-Term Debt: $longTermDebt');
//       print('Shareholders Equity: $shareholdersEquity');
//       print('Operating Cash Flow: $operatingCashFlow');
//       print('Investing Cash Flow: $investingCashFlow');
//       print('Financing Cash Flow: $financingCashFlow');
//       print('Cash & Equivalents: $cashEquivalents');
//       print('P/B Ratio: $pbRatio');
//       print('P/S Ratio: $psRatio');
//       print('Market Cap: $marketCap');
//       print('================================\n');
      
//       setState(() {
//         _stockData = {
//           'Company Name': widget.companyName,
//           'Symbol': symbol,
//           'Current Price': currentPrice?.toString() ?? 'N/A',
//           'High': high?.toString() ?? 'N/A',
//           'Low': low?.toString() ?? 'N/A',
//           'Open': open?.toString() ?? 'N/A',
//           'Change Value': changeValue?.toStringAsFixed(2) ?? 'N/A',
//           'Change Percent': changePct?.toStringAsFixed(2) ?? 'N/A',
//           'Volume': volume?.toString() ?? 'N/A',
//           // Income Statement
//           'Revenue': revenue ?? 'N/A',
//           'EBITDA': ebitda ?? 'N/A',
//           'EBIT': ebit ?? 'N/A',
//           'Net Profit': netProfit ?? 'N/A',
//           'EPS': eps ?? 'N/A',
//           'Stock P/E': peRatio ?? 'N/A',
//           // Balance Sheet
//           'Total Assets': totalAssets ?? 'N/A',
//           'Total Liabilities': totalLiabilities ?? 'N/A',
//           'Long-Term Debt': longTermDebt ?? 'N/A',
//           'Shareholders Equity': shareholdersEquity ?? 'N/A',
//           // Cash Flow
//           'Operating Cash Flow': operatingCashFlow ?? 'N/A',
//           'Investing Cash Flow': investingCashFlow ?? 'N/A',
//           'Financing Cash Flow': financingCashFlow ?? 'N/A',
//           'Cash & Equivalents': cashEquivalents ?? 'N/A',
//           // Valuation
//           'P/B Ratio': pbRatio ?? 'N/A',
//           'P/S Ratio': psRatio ?? 'N/A',
//           'Market Cap': marketCap ?? 'N/A',
//         };
//         _stockError = '';
//       });
//     } catch (e, stackTrace) {
//       print('=== FATAL ERROR ===');
//       print('Error: $e');
//       print('Stack trace: $stackTrace');
//       setState(() {
//         _stockError = "Stock data fetch failed: $e";
//       });
//     }

//     setState(() => _isLoadingStock = false);
//   }

//   Future<void> _fetchCompanyNews() async {
//     setState(() {
//       _isLoading = true;
//       _error = '';
//     });

//     try {
//       final encodedName = Uri.encodeComponent(widget.companyName);
//       final url = "http://51.20.136.45:5000/api/filtered-news/company/$encodedName";
      
//       print('📰📰📰 Fetching news for: ${widget.companyName}');
//       print('📰📰📰 URL: $url');
      
//       final resp = await http.get(Uri.parse(url));
      
//       print('📰📰📰 News Response Status: ${resp.statusCode}');
//       print('📰📰📰 News Response Body Length: ${resp.body.length}');

//       if (resp.statusCode == 200) {
//         final data = json.decode(resp.body);
//         print('📰📰📰 News data type: ${data.runtimeType}');
//         print('📰📰📰 News count: ${data is List ? data.length : 0}');
        
//         setState(() {
//           _news = (data as List).cast<Map<String, dynamic>>();
//         });
        
//         if (_news.isEmpty) {
//           print('⚠️ No news found for ${widget.companyName}');
//         } else {
//           print('✅ Loaded ${_news.length} news articles');
//         }
//       } else {
//         final errorBody = resp.body;
//         setState(() {
//           _error =
//               "Failed to fetch news\nStatus: ${resp.statusCode}\nError: $errorBody";
//         });
//         print('❌ News fetch failed: ${resp.statusCode}');
//       }
//     } catch (e, stackTrace) {
//       print('❌❌❌ Exception in _fetchCompanyNews: $e');
//       print('Stack trace: $stackTrace');
//       setState(() {
//         _error = "DB fetch failed: $e";
//       });
//     }

//     setState(() => _isLoading = false);
//   }

//   Future<void> _fetchAIOverview() async {
//     setState(() {
//       _isLoadingAI = true;
//       _aiError = '';
//     });

//     try {
//       var symbol = widget.companySymbol.toUpperCase();
//       if (symbol.endsWith('.NSE') || symbol.endsWith('.BSE')) {
//         symbol = symbol.split('.').first;
//       }

//       final url = Uri.parse(
//         'http://51.20.136.45:5001/api/ai-overview/$symbol'
//       ).replace(queryParameters: {
//         'company_name': widget.companyName,
//         'v': '5'
//       });

//       print('🔥🔥🔥 CALLING AI OVERVIEW: $url');
      
//       final resp = await http.get(url).timeout(const Duration(seconds: 150));
      
//       print('🔥🔥🔥 RESPONSE STATUS: ${resp.statusCode}');
//       print('🔥🔥🔥 RESPONSE BODY: ${resp.body.substring(0, resp.body.length > 200 ? 200 : resp.body.length)}');

//       if (resp.statusCode == 200) {
//         final data = json.decode(resp.body);
//         if (data['success'] == true) {
//           setState(() {
//             _aiOverview = {
//               'overview': data['overview'],
//               'generated_at': data['generated_at'],
//               'company_name': data['company_name'],
//               'symbol': data['symbol'],
//             };
//           });
//           print('✅ AI Overview loaded successfully');
//         } else {
//           setState(() {
//             _aiError = data['error'] ?? "Failed to generate AI overview";
//           });
//           print('❌ API returned success=false: ${data['error']}');
//         }
//       } else {
//         setState(() {
//           _aiError = "Failed to fetch AI overview (${resp.statusCode})";
//         });
//         print('❌ HTTP Error: ${resp.statusCode}');
//       }
//     } catch (e, stackTrace) {
//       print('❌❌❌ EXCEPTION in _fetchAIOverview: $e');
//       print('Stack trace: $stackTrace');
//       setState(() {
//         _aiError = "Connection failed: $e";
//         _aiOverview = null;
//       });
//     }

//     setState(() => _isLoadingAI = false);
//   }

//   Future<void> _fetchAIInsight() async {
//     setState(() {
//       _isLoadingInsight = true;
//       _insightError = '';
//     });

//     try {
//       var symbol = widget.companySymbol.toUpperCase();
//       if (symbol.endsWith('.NSE') || symbol.endsWith('.BSE')) {
//         symbol = symbol.split('.').first;
//       }

//       final url = Uri.parse(
//         'http://51.20.136.45:5001/api/ai-insight/$symbol'
//       ).replace(queryParameters: {
//         'company_name': widget.companyName,
//         'v': '5'
//       });

//       print('🔥🔥🔥 CALLING AI INSIGHT: $url');
      
//       final resp = await http.get(url).timeout(const Duration(seconds: 150));
      
//       print('🔥🔥🔥 INSIGHT RESPONSE STATUS: ${resp.statusCode}');
//       print('🔥🔥🔥 INSIGHT RESPONSE BODY: ${resp.body}');

//       if (resp.statusCode == 200) {
//         final data = json.decode(resp.body);
//         if (data['success'] == true) {
//           setState(() {
//             _aiInsight = {
//               'insight': data['insight'],
//               'generated_at': data['generated_at'],
//             };
//           });
//           print('✅ AI Insight loaded successfully');
//         } else {
//           setState(() {
//             _insightError = data['error'] ?? "Failed to generate AI insight";
//           });
//           print('❌ Insight API returned success=false');
//         }
//       } else {
//         setState(() {
//           _insightError = "Failed to fetch AI insight (${resp.statusCode})";
//         });
//         print('❌ Insight HTTP Error: ${resp.statusCode}');
//       }
//     } catch (e, stackTrace) {
//       print('❌❌❌ EXCEPTION in _fetchAIInsight: $e');
//       print('Stack trace: $stackTrace');
//       setState(() {
//         _insightError = "Connection failed: $e";
//       });
//     }

//     setState(() => _isLoadingInsight = false);
//   }

//   Future<void> _fetchCompanyEvents() async {
//     setState(() {
//       _isLoadingEvents = true;
//       _eventsError = '';
//     });

//     try {
//       final encodedName = Uri.encodeComponent(widget.companyName);
//       final url = "http://51.20.136.45:5000/api/events/company/$encodedName";
      
//       print('🎉🎉🎉 Fetching events for: ${widget.companyName}');
      
//       final resp = await http.get(Uri.parse(url));
      
//       print('🎉🎉🎉 Events Response Status: ${resp.statusCode}');

//       if (resp.statusCode == 200) {
//         final data = json.decode(resp.body);
//         setState(() {
//           _companyEvents = (data as List).cast<Map<String, dynamic>>();
//         });
//         print('✅ Loaded ${_companyEvents.length} events');
//       } else {
//         setState(() {
//           _eventsError = "Failed to fetch events (${resp.statusCode})";
//         });
//       }
//     } catch (e) {
//       print('❌ Exception in _fetchCompanyEvents: $e');
//       setState(() {
//         _eventsError = "Failed to load events: $e";
//       });
//     }

//     setState(() => _isLoadingEvents = false);
//   }

//   Future<void> _fetchChartData(String timeframe) async {
//     setState(() {
//       _isLoadingChart = true;
//       _chartError = '';
//       _selectedTimeframe = timeframe;
//     });

//     try {
//       var symbol = widget.companySymbol.toUpperCase();
//       if (symbol.endsWith('.NSE') || symbol.endsWith('.BSE')) {
//         symbol = symbol.split('.').first;
//       }

//       // Yahoo Finance parameters based on timeframe
//       String range, interval;
//       switch (timeframe) {
//         case '1W':
//           range = '7d';
//           interval = '1d';
//           break;
//         case '1Y':
//           range = '1y';
//           interval = '1wk';
//           break;
//         case '1M':
//         default:
//           range = '1mo';
//           interval = '1d';
//       }

//       final url = Uri.parse(
//         'https://query1.finance.yahoo.com/v8/finance/chart/$symbol.NS'
//       ).replace(queryParameters: {
//         'range': range,
//         'interval': interval,
//       });

//       print('Fetching Yahoo Finance chart: $url');

//       final response = await http.get(url).timeout(const Duration(seconds: 10));

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
        
//         if (data['chart']?['result'] == null || data['chart']['result'].isEmpty) {
//           setState(() {
//             _chartError = 'No chart data available';
//             _chartData = [];
//           });
//           return;
//         }

//         final result = data['chart']['result'][0];
//         final timestamps = result['timestamp'] as List?;
//         final quote = result['indicators']?['quote']?[0];

//         if (timestamps == null || quote == null) {
//           setState(() {
//             _chartError = 'Invalid chart data format';
//             _chartData = [];
//           });
//           return;
//         }

//         final opens = quote['open'] as List?;
//         final highs = quote['high'] as List?;
//         final lows = quote['low'] as List?;
//         final closes = quote['close'] as List?;

//         if (opens == null || highs == null || lows == null || closes == null) {
//           setState(() {
//             _chartError = 'Missing OHLC data';
//             _chartData = [];
//           });
//           return;
//         }

//         List<Map<String, dynamic>> chartData = [];
//         for (int i = 0; i < timestamps.length; i++) {
//           if (opens[i] != null && highs[i] != null && 
//               lows[i] != null && closes[i] != null) {
//             chartData.add({
//               'time': timestamps[i],
//               'open': opens[i].toDouble(),
//               'high': highs[i].toDouble(),
//               'low': lows[i].toDouble(),
//               'close': closes[i].toDouble(),
//             });
//           }
//         }

//         setState(() {
//           _chartData = chartData;
//           _chartError = '';
//         });

//         // Load or update chart
//         if (_chartInitialized) {
//           _updateChartData();
//         } else {
//           _webViewController?.loadHtmlString(_getTradingViewHTML());
//         }

//       } else {
//         setState(() {
//           _chartError = 'Failed to fetch chart data (${response.statusCode})';
//           _chartData = [];
//         });
//       }
//     } catch (e) {
//       print('Chart fetch error: $e');
//       setState(() {
//         _chartError = 'Chart not available';
//         _chartData = [];
//       });
//     }

//     setState(() => _isLoadingChart = false);
//   }

//   void _updateChartData() {
//     if (_chartData.isEmpty || _webViewController == null) return;
    
//     final jsonData = json.encode(_chartData);
//     _webViewController!.runJavaScript('''
//       if (window.candlestickSeries && window.chart) {
//         window.candlestickSeries.setData($jsonData);
//         window.chart.timeScale().fitContent();
//       }
//     ''');
//   }

//   String _formatDate(String? dateString) {
//     if (dateString == null || dateString.isEmpty) return "Date not available";
//     try {
//       final date = DateFormat("EEEE, MMM dd, yyyy HH:mm:ss").parse(dateString);
//       return DateFormat.yMMMd().add_jm().format(date);
//     } catch (e) {
//       return dateString;
//     }
//   }

//   String _parseIndianNumber(String? value) {
//     if (value == null || value.isEmpty) return 'N/A';
//     return value.replaceAll(',', '');
//   }

//   String _formatMarketCap() {
//     final marketCap = _stockData?['Market Cap'];
//     if (marketCap == null || marketCap.toString() == 'N/A') return 'N/A';

//     try {
//       final value = double.parse(_parseIndianNumber(marketCap.toString()));
//       if (value >= 100000) {
//         return '₹${(value / 100000).toStringAsFixed(2)}L Cr';
//       } else if (value >= 1000) {
//         return '₹${(value / 1000).toStringAsFixed(2)}K Cr';
//       }
//       return '₹${value.toStringAsFixed(2)} Cr';
//     } catch (e) {
//       return '₹${marketCap.toString()} Cr';
//     }
//   }

//   String _getTradingViewHTML() {
//     final jsonData = json.encode(_chartData);
    
//     return '''
// <!DOCTYPE html>
// <html>
// <head>
//   <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
//   <script src="https://unpkg.com/lightweight-charts@4.1.0/dist/lightweight-charts.standalone.production.js"></script>
//   <style>
//     * { margin: 0; padding: 0; box-sizing: border-box; }
//     body { 
//       margin: 0; 
//       padding: 0; 
//       font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
//       overflow: hidden;
//     }
//     #chart { width: 100%; height: 100vh; }
//     #loading {
//       position: absolute;
//       top: 50%;
//       left: 50%;
//       transform: translate(-50%, -50%);
//       font-size: 14px;
//       color: #666;
//     }
//   </style>
// </head>
// <body>
//   <div id="loading">Loading chart...</div>
//   <div id="chart"></div>
//   <script>
//     try {
//       // Wait for library to load
//       if (typeof LightweightCharts === 'undefined') {
//         document.getElementById('loading').textContent = 'Chart library loading...';
//         setTimeout(() => location.reload(), 2000);
//         throw new Error('LightweightCharts not loaded');
//       }

//       document.getElementById('loading').style.display = 'none';

//       const chartContainer = document.getElementById('chart');
//       const chart = LightweightCharts.createChart(chartContainer, {
//         width: chartContainer.clientWidth,
//         height: chartContainer.clientHeight,
//         layout: {
//           background: { color: '#ffffff' },
//           textColor: '#333',
//         },
//         grid: {
//           vertLines: { color: '#f0f0f0' },
//           horzLines: { color: '#f0f0f0' },
//         },
//         crosshair: {
//           mode: LightweightCharts.CrosshairMode.Normal,
//         },
//         rightPriceScale: {
//           borderColor: '#e0e0e0',
//         },
//         timeScale: {
//           borderColor: '#e0e0e0',
//           timeVisible: true,
//           secondsVisible: false,
//         },
//       });

//       const candlestickSeries = chart.addCandlestickSeries({
//         upColor: '#26a69a',
//         downColor: '#ef5350',
//         borderVisible: false,
//         wickUpColor: '#26a69a',
//         wickDownColor: '#ef5350',
//       });

//       // Expose to global scope for updates
//       window.chart = chart;
//       window.candlestickSeries = candlestickSeries;

//       const data = $jsonData;
      
//       if (data && data.length > 0) {
//         candlestickSeries.setData(data);
//         chart.timeScale().fitContent();
//       } else {
//         document.getElementById('loading').style.display = 'block';
//         document.getElementById('loading').textContent = 'No data available';
//       }

//       // Handle resize
//       window.addEventListener('resize', () => {
//         chart.applyOptions({ 
//           width: chartContainer.clientWidth,
//           height: chartContainer.clientHeight 
//         });
//       });

//     } catch (error) {
//       console.error('Chart error:', error);
//       document.getElementById('loading').textContent = 'Chart error: ' + error.message;
//     }
//   </script>
// </body>
// </html>
//     ''';
//   }

//   Widget _buildChartWidget() {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 24),
//       padding: const EdgeInsets.all(24),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(24),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.08),
//             blurRadius: 20,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         children: [
//           // Chart area with mint background
//           Container(
//             height: 280,
//             decoration: BoxDecoration(
//               color: const Color(0xFFEAF8F4),
//               borderRadius: BorderRadius.circular(16),
//             ),
//             child: Stack(
//               children: [
//                 // Chart placeholder or WebView
//                 Padding(
//                   padding: const EdgeInsets.all(16),
//                   child: _isLoadingChart
//                       ? const Center(
//                           child: CircularProgressIndicator(
//                             color: Color(0xFF007A5A),
//                           ),
//                         )
//                       : _chartError.isNotEmpty
//                           ? Center(
//                               child: Text(
//                                 _chartError,
//                                 style: GoogleFonts.manrope(
//                                   fontSize: 14,
//                                   color: const Color(0xFF5A5D72),
//                                 ),
//                                 textAlign: TextAlign.center,
//                               ),
//                             )
//                           : _chartData.isEmpty
//                               ? Center(
//                                   child: Text(
//                                     'No chart data available',
//                                     style: GoogleFonts.manrope(
//                                       fontSize: 14,
//                                       color: const Color(0xFF5A5D72),
//                                     ),
//                                   ),
//                                 )
//                               : ClipRRect(
//                                   borderRadius: BorderRadius.circular(16),
//                                   child: _webViewController != null
//                                       ? WebViewWidget(controller: _webViewController!)
//                                       : const SizedBox.shrink(),
//                                 ),
//                 ),
//                 // Floating Current Price Badge
//                 if (_stockData != null)
//                   Positioned(
//                     top: 16,
//                     right: 16,
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                       decoration: BoxDecoration(
//                         color: Colors.white,
//                         borderRadius: BorderRadius.circular(16),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.black.withOpacity(0.08),
//                             blurRadius: 12,
//                             offset: const Offset(0, 4),
//                           ),
//                         ],
//                       ),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.end,
//                         children: [
//                           Text(
//                             'CURRENT',
//                             style: GoogleFonts.manrope(
//                               fontSize: 12,
//                               fontWeight: FontWeight.w500,
//                               color: const Color(0xFF5A5D72),
//                             ),
//                           ),
//                           const SizedBox(height: 4),
//                           Text(
//                             '₹${_stockData!['Current Price']}',
//                             style: GoogleFonts.manrope(
//                               fontSize: 18,
//                               fontWeight: FontWeight.w700,
//                               color: const Color(0xFF007A5A),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 24),
//           // Segmented Timeframe Selector
//           Container(
//             height: 76,
//             padding: const EdgeInsets.all(8),
//             decoration: BoxDecoration(
//               color: const Color(0xFFF1F3F6),
//               borderRadius: BorderRadius.circular(16),
//             ),
//             child: Row(
//               children: [
//                 _buildTimeframeButton('1D'),
//                 _buildTimeframeButton('1W'),
//                 _buildTimeframeButton('1M'),
//                 _buildTimeframeButton('1Y'),
//                 _buildTimeframeButton('5Y'),
//                 _buildTimeframeButton('ALL'),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildTimeframeButton(String timeframe) {
//     final isSelected = _selectedTimeframe == timeframe;
//     return Expanded(
//       child: GestureDetector(
//         onTap: () => _fetchChartData(timeframe),
//         child: Container(
//           margin: const EdgeInsets.symmetric(horizontal: 4),
//           decoration: BoxDecoration(
//             color: isSelected ? Colors.white : Colors.transparent,
//             borderRadius: BorderRadius.circular(14),
//             boxShadow: isSelected
//                 ? [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.06),
//                       blurRadius: 8,
//                       offset: const Offset(0, 2),
//                     ),
//                   ]
//                 : null,
//           ),
//           child: Center(
//             child: Text(
//               timeframe,
//               style: GoogleFonts.manrope(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w600,
//                 color: isSelected ? const Color(0xFF007A5A) : const Color(0xFF5A5D72),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildOverviewTab() {
//     return SingleChildScrollView(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const SizedBox(height: 40),
          
//           // Chart Widget
//           _buildChartWidget(),
          
//           const SizedBox(height: 40),

//           // AI Overview Section
//           Container(
//             margin: const EdgeInsets.symmetric(horizontal: 24),
//             padding: const EdgeInsets.all(32),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(24),
//               border: Border.all(color: const Color(0xFFF2DCDC)),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   children: [
//                     Row(
//                       children: [
//                         const Icon(
//                           Icons.auto_awesome,
//                           size: 24,
//                           color: Color(0xFFE54350),
//                         ),
//                         const SizedBox(width: 12),
//                         Text(
//                           'AI Overview',
//                           style: GoogleFonts.manrope(
//                             fontSize: 18,
//                             fontWeight: FontWeight.w500,
//                             color: const Color(0xFFE54350),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 24),
//                 _isLoadingAI
//                     ? const Center(
//                         child: Padding(
//                           padding: EdgeInsets.all(32),
//                           child: CircularProgressIndicator(
//                             color: Color(0xFFE54350),
//                           ),
//                         ),
//                       )
//                     : _aiError.isNotEmpty && _aiOverview == null
//                         ? Container(
//                             padding: const EdgeInsets.all(16),
//                             decoration: BoxDecoration(
//                               color: const Color(0xFFFFF3F3),
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                             child: Row(
//                               children: [
//                                 const Icon(
//                                   Icons.error_outline,
//                                   color: Color(0xFFE54350),
//                                   size: 20,
//                                 ),
//                                 const SizedBox(width: 12),
//                                 Expanded(
//                                   child: Text(
//                                     _aiError,
//                                     style: GoogleFonts.manrope(
//                                       fontSize: 14,
//                                       color: const Color(0xFFE54350),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           )
//                         : _buildFormattedOverviewText(
//                             _aiOverview?['overview'] ?? 
//                             'Unable to generate overview. Please try again later.',
//                           ),
//               ],
//             ),
//           ),
          
//           const SizedBox(height: 48),
//         ],
//       ),
//     );
//   }

//   Widget _buildFinancialsTab() {
//     if (_isLoadingStock) {
//       return const Center(
//         child: Padding(
//           padding: EdgeInsets.all(20),
//           child: CircularProgressIndicator(),
//         ),
//       );
//     }

//     if (_stockError.isNotEmpty) {
//       return Center(
//         child: Padding(
//           padding: const EdgeInsets.all(20),
//           child: Text(
//             _stockError,
//             style: const TextStyle(color: Colors.red),
//             textAlign: TextAlign.center,
//           ),
//         ),
//       );
//     }

//     return SingleChildScrollView(
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // 1. Income Statement
//           _buildFinancialSection(
//             title: 'INCOME STATEMENT (ANNUAL)',
//             subtitle: 'Scale, profitability, and earnings strength',
//             rows: [
//               _buildFundamentalRow('Revenue', _stockData?['Revenue'] ?? 'N/A', 'EBITDA', _stockData?['EBITDA'] ?? 'N/A'),
//               _buildFundamentalRow('EBIT', _stockData?['EBIT'] ?? 'N/A', 'Net Profit', _stockData?['Net Profit'] ?? 'N/A'),
//               _buildFundamentalRow('EPS', _stockData?['EPS'] ?? 'N/A', 'P/E Ratio', _stockData?['Stock P/E'] ?? 'N/A'),
//             ],
//           ),

//           // 2. Balance Sheet
//           _buildFinancialSection(
//             title: 'BALANCE SHEET (LATEST ANNUAL)',
//             subtitle: 'Snapshot of financial position',
//             rows: [
//               _buildFundamentalRow('Total Assets', _stockData?['Total Assets'] ?? 'N/A', 'Total Liabilities', _stockData?['Total Liabilities'] ?? 'N/A'),
//               _buildFundamentalRow('Long-Term Debt', _stockData?['Long-Term Debt'] ?? 'N/A', 'Cash & Equivalents', _stockData?['Cash & Equivalents'] ?? 'N/A'),
//               _buildFundamentalRow('Shareholders\' Equity', _stockData?['Shareholders Equity'] ?? 'N/A', '', ''),
//             ],
//           ),

//           // 3. Cash Flow Statement
//           _buildFinancialSection(
//             title: 'CASH FLOW STATEMENT (ANNUAL)',
//             subtitle: 'Cash generation and sustainability',
//             rows: [
//               _buildFundamentalRow('Operating Cash Flow', _stockData?['Operating Cash Flow'] ?? 'N/A', 'Investing Cash Flow', _stockData?['Investing Cash Flow'] ?? 'N/A'),
//               _buildFundamentalRow('Financing Cash Flow', _stockData?['Financing Cash Flow'] ?? 'N/A', 'Free Cash Flow', 'N/A'),
//             ],
//           ),

//           // 4. Valuation & Returns
//           Container(
//             margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: Colors.grey.shade300),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'VALUATION & RETURNS',
//                   style: TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.bold,
//                     letterSpacing: 0.5,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   'Is the stock reasonably valued?',
//                   style: TextStyle(
//                     fontSize: 11,
//                     color: Colors.grey.shade600,
//                   ),
//                 ),
//                 const SizedBox(height: 16),
//                 Wrap(
//                   spacing: 8,
//                   runSpacing: 8,
//                   children: [
//                     _buildValuationChip('P/E', _stockData?['Stock P/E'] ?? 'N/A'),
//                     _buildValuationChip('P/B', _stockData?['P/B Ratio'] ?? 'N/A'),
//                     _buildValuationChip('P/S', _stockData?['P/S Ratio'] ?? 'N/A'),
//                     _buildValuationChip('Market Cap', _formatMarketCap()),
//                   ],
//                 ),
//               ],
//             ),
//           ),

//           // 5. AI Insight Section (at the bottom)
//           Container(
//             margin: const EdgeInsets.only(left: 24, right: 24, bottom: 32),
//             padding: const EdgeInsets.all(24),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(16),
//               border: Border.all(color: const Color(0xFFE5E7EB)),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     Row(
//                       children: [
//                         const Icon(
//                           Icons.lightbulb_outline,
//                           size: 24,
//                           color: Color(0xFFE54350),
//                         ),
//                         const SizedBox(width: 12),
//                         Text(
//                           'AI INSIGHT',
//                           style: GoogleFonts.manrope(
//                             fontSize: 20,
//                             fontWeight: FontWeight.w700,
//                             color: const Color(0xFF191C1E),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 24),
//                 _isLoadingInsight
//                     ? const Center(
//                         child: Padding(
//                           padding: EdgeInsets.all(32),
//                           child: CircularProgressIndicator(
//                             color: Color(0xFFE54350),
//                           ),
//                         ),
//                       )
//                     : _insightError.isNotEmpty && _aiInsight == null
//                         ? Text(
//                             _insightError,
//                             style: GoogleFonts.manrope(
//                               fontSize: 14,
//                               color: const Color(0xFFA0A0A0),
//                             ),
//                           )
//                         : _buildFormattedText(
//                             _aiInsight?['insight'] ?? 
//                             'AI insight is limited due to incomplete financial data availability.',
//                           ),
//               ],
//             ),
//           ),
//           const SizedBox(height: 16),
//         ],
//       ),
//     );
//   }

//   Widget _buildFinancialSection({
//     required String title,
//     required String subtitle,
//     required List<Widget> rows,
//   }) {
//     return Container(
//       margin: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
//       padding: const EdgeInsets.all(24),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(16),
//         border: Border.all(color: const Color(0xFFE5E7EB)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             title,
//             style: GoogleFonts.manrope(
//               fontSize: 16,
//               fontWeight: FontWeight.w700,
//               letterSpacing: 0.5,
//               color: const Color(0xFF191C1E),
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             subtitle,
//             style: GoogleFonts.manrope(
//               fontSize: 13,
//               fontWeight: FontWeight.w400,
//               color: const Color(0xFFA0A0A0),
//             ),
//           ),
//           const SizedBox(height: 20),
//           ...rows.map((row) => Padding(
//             padding: const EdgeInsets.only(bottom: 16),
//             child: row,
//           )).toList(),
//         ],
//       ),
//     );
//   }

//   Widget _buildValuationChip(String label, String value) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       decoration: BoxDecoration(
//         color: Colors.grey.shade50,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: Colors.grey.shade200),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             label,
//             style: TextStyle(
//               fontSize: 11,
//               color: Colors.grey.shade600,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             value,
//             style: const TextStyle(
//               fontSize: 14,
//               fontWeight: FontWeight.bold,
//               color: Color(0xFF2D3748),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   String formatValue(String val) {
//     if (val == 'N/A' || val == 'N/A (Bank)') return val;
    
//     try {
//       final numVal = double.parse(val);
      
//       // Values are already in Crores from the API
//       // Format based on magnitude
//       if (numVal >= 100000) {
//         // Convert to Lakh Crores
//         return '₹${(numVal / 100000).toStringAsFixed(2)}L Cr';
//       } else if (numVal >= 10000) {
//         // Keep in Crores with thousand separator
//         return '₹${numVal.toStringAsFixed(0)} Cr';
//       } else if (numVal >= 1000) {
//         return '₹${(numVal / 1000).toStringAsFixed(2)}K Cr';
//       } else if (numVal < 100) {
//         // For EPS and P/E ratios (small values)
//         return numVal.toStringAsFixed(2);
//       }
//       return '₹${numVal.toStringAsFixed(2)} Cr';
//     } catch (e) {
//       return val;
//     }
//   }

//   Widget _buildFundamentalRow(String label1, String value1, String label2, String value2) {
//     // Format value1
//     String formattedValue1;
//     if (label1 == 'EPS' || label1 == 'P/E Ratio') {
//       formattedValue1 = value1 == 'N/A' ? value1 : '₹$value1';
//     } else {
//       formattedValue1 = formatValue(value1);
//     }

//     // Format value2
//     String formattedValue2;
//     if (label2 == 'EPS' || label2 == 'P/E Ratio') {
//       formattedValue2 = value2 == 'N/A' ? value2 : value2.endsWith('x') ? value2 : '${value2}x';
//     } else {
//       formattedValue2 = formatValue(value2);
//     }

//     // If label2 is empty, show only one column
//     if (label2.isEmpty) {
//       return Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             label1,
//             style: TextStyle(
//               fontSize: 12,
//               color: Colors.grey.shade600,
//             ),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             formattedValue1,
//             style: const TextStyle(
//               fontSize: 14,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//         ],
//       );
//     }

//     return Row(
//       children: [
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 label1,
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: Colors.grey.shade600,
//                 ),
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 formattedValue1,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 label2,
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: Colors.grey.shade600,
//                 ),
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 formattedValue2,
//                 style: const TextStyle(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildNewsTab() {
//     if (_isLoading) {
//       return const Center(child: CircularProgressIndicator());
//     }
//     if (_error.isNotEmpty) {
//       return Center(child: Text(_error, style: const TextStyle(color: Colors.red)));
//     }
//     if (_news.isEmpty) {
//       return const Center(child: Text('No news available'));
//     }
//     return ListView.builder(
//       padding: const EdgeInsets.all(16),
//       itemCount: _news.length,
//       itemBuilder: (context, index) => _buildNewsItem(_news[index]),
//     );
//   }

//   Widget _buildNewsItem(Map<String, dynamic> article) {
//     final headline = article["Headline"] ?? "No headline";
//     final publishedAt = article["PublishedAt"] ?? "";
//     final summary = article["summary"] ?? "";

//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: Colors.grey.shade200),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.06),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Published Date
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             decoration: BoxDecoration(
//               color: Colors.grey.shade50,
//               borderRadius: const BorderRadius.only(
//                 topLeft: Radius.circular(14),
//                 topRight: Radius.circular(14),
//               ),
//             ),
//             child: Row(
//               children: [
//                 Icon(Icons.calendar_today,
//                     size: 14, color: Colors.grey.shade600),
//                 const SizedBox(width: 6),
//                 Text(
//                   _formatDate(publishedAt),
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: Colors.grey.shade600,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           // Headline and Summary
//           Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   headline,
//                   style: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                     color: Color(0xFF2D3748),
//                   ),
//                 ),
//                 if (summary.isNotEmpty) ...[
//                   const SizedBox(height: 12),
//                   Container(
//                     padding: const EdgeInsets.all(12),
//                     decoration: BoxDecoration(
//                       color: const Color(0xFFF8F9FA),
//                       borderRadius: BorderRadius.circular(8),
//                       border: Border.all(color: Colors.grey.shade100),
//                     ),
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           "Summary",
//                           style: TextStyle(
//                             fontSize: 14,
//                             fontWeight: FontWeight.w600,
//                             color: Color(0xFFEA6B6B),
//                           ),
//                         ),
//                         const SizedBox(height: 6),
//                         Text(
//                           summary,
//                           style: TextStyle(
//                             fontSize: 14,
//                             color: Colors.grey.shade800,
//                             height: 1.5,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//    BottomNavigationBarItem _navItem({
//   required String label,
//   required String active,
//   required String inactive,
//   required int index,
// }) {
//   final bool selected = _bottomIndex == index;

//   return BottomNavigationBarItem(
//     icon: SvgPicture.asset(
//       selected ? active : inactive,
//       height: 22,
//     ),
//     label: label,
//     tooltip: label,
//   );
// }

//   @override
//   Widget build(BuildContext context) {
//     final currentPrice = _stockData?['Current Price']?.toString() ?? '0.00';
//     final changeValue = _stockData?['Change Value']?.toString() ?? '0';
//     final changePct = _stockData?['Change Percent']?.toString() ?? '0';
    
//     bool isPositive = !changeValue.startsWith('-');

//     return Scaffold(
//       backgroundColor: const Color(0xFFF5F6F8),
//       body: SafeArea(
//         child: Column(
//           children: [
//             // Top Section with Back Button, Company Name, and Price
//             Container(
//               color: const Color(0xFFF5F6F8),
//               padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
//               child: Column(
//                 children: [
//                   Row(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // Back Button
//                       GestureDetector(
//                         onTap: () => Navigator.pop(context),
//                         child: Container(
//                           width: 48,
//                           height: 48,
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             shape: BoxShape.circle,
//                             boxShadow: [
//                               BoxShadow(
//                                 color: Colors.black.withOpacity(0.06),
//                                 blurRadius: 12,
//                                 offset: const Offset(0, 4),
//                               ),
//                             ],
//                           ),
//                           child: const Center(
//                             child: Icon(
//                               Icons.arrow_back,
//                               color: Color(0xFFE54350),
//                               size: 24,
//                             ),
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 16),
//                       // Company Name and Price
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               widget.companyName,
//                               style: GoogleFonts.manrope(
//                                 fontSize: 24,
//                                 fontWeight: FontWeight.w400,
//                                 height: 38.4 / 24,
//                                 letterSpacing: -0.64,
//                                 color: const Color(0xFF191C1E),
//                               ),
//                             ),
//                             const SizedBox(height: 12),
//                             Row(
//                               children: [
//                                 Text(
//                                   'Rs. ₹$currentPrice',
//                                   style: GoogleFonts.manrope(
//                                     fontSize: 24,
//                                     fontWeight: FontWeight.w600,
//                                     height: 31.2 / 24,
//                                     letterSpacing: -0.24,
//                                     color: const Color(0xFF191C1E),
//                                   ),
//                                 ),
//                                 const SizedBox(width: 12),
//                                 Container(
//                                   height: 36,
//                                   padding: const EdgeInsets.symmetric(horizontal: 16),
//                                   decoration: BoxDecoration(
//                                     color: const Color(0xFFDDF4EC),
//                                     borderRadius: BorderRadius.circular(999),
//                                   ),
//                                   child: Center(
//                                     child: Text(
//                                       '${isPositive ? '+' : ''}$changePct%',
//                                       style: GoogleFonts.manrope(
//                                         fontSize: 16,
//                                         fontWeight: FontWeight.w600,
//                                         color: const Color(0xFF007A5A),
//                                       ),
//                                     ),
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 32),
//                   // Tabs
//                   Container(
//                     height: 48,
//                     decoration: BoxDecoration(
//                       border: Border(
//                         bottom: BorderSide(
//                           color: Colors.grey.shade200,
//                           width: 1,
//                         ),
//                       ),
//                     ),
//                     child: Row(
//                       children: [
//                         _buildTabItem('OVERVIEW', 0),
//                         _buildTabItem('FINANCIAL', 1),
//                         _buildTabItem('NEWS', 2),
//                         _buildTabItem('EVENTS', 3),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             // Tab Content
//             Expanded(
//               child: TabBarView(
//                 controller: _tabController,
//                 children: [
//                   _buildOverviewTab(),
//                   _buildFinancialsTab(),
//                   _buildNewsTab(),
//                   _buildEventsTab(),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//       bottomNavigationBar: Container(
//         decoration: const BoxDecoration(
//           color: Colors.white,
//           border: Border(
//             top: BorderSide(color: Color(0xFFE0E0E0), width: 0.8),
//           ),
//         ),
//         child: BottomNavigationBar(
//           currentIndex: _bottomIndex,
//           type: BottomNavigationBarType.fixed,
//           backgroundColor: Colors.white,
//           elevation: 0,
//           selectedItemColor: const Color(0xFFEA6B6B),
//           unselectedItemColor: Colors.black54,
//           showUnselectedLabels: true,
//           selectedLabelStyle: GoogleFonts.poppins(
//             fontSize: 13,
//             fontWeight: FontWeight.w600,
//             height: 1.2,
//           ),
//           unselectedLabelStyle: GoogleFonts.poppins(
//             fontSize: 13,
//             fontWeight: FontWeight.w400,
//             height: 1.2,
//           ),
//           onTap: (index) {
//             if (index == _bottomIndex) return;

//             Widget? destination;

//             switch (index) {
//               case 0:
//                 destination = const NewsFeedScreen();
//                 break;
//               case 1:
//                 destination = const IndexScreen();
//                 break;
//               case 2:
//                 destination = const ChatbotScreen();
//                 break;
//               case 3:
//                 destination = const EventsScreen();
//                 break;
//               case 4:
//                 destination = const SavedNewsFeedScreen();
//                 break;
//               default:
//                 return;
//             }

//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(builder: (_) => destination!),
//             );
//           },
//           items: [
//             _navItem(label: "NEWS", active: 'assets/icons/News Red.svg', inactive: 'assets/icons/News.svg', index: 0),
//             _navItem(label: "INDEX", active: 'assets/icons/Index red.svg', inactive: 'assets/icons/Index.svg', index: 1),
//             _navItem(label: "ASK AI", active: 'assets/icons/Ask AI Red.svg', inactive: 'assets/icons/Ask AI.svg', index: 2),
//             _navItem(label: "EVENTS", active: 'assets/icons/Calender Red.svg', inactive: 'assets/icons/Calender.svg', index: 3),
//             _navItem(label: "SAVED", active: 'assets/icons/Save red.svg', inactive: 'assets/icons/Save.svg', index: 4),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildTabItem(String label, int index) {
//     final isSelected = _selectedTabIndex == index;
//     return Expanded(
//       child: GestureDetector(
//         onTap: () {
//           _tabController.animateTo(index);
//         },
//         child: Container(
//           decoration: BoxDecoration(
//             border: Border(
//               bottom: BorderSide(
//                 color: isSelected ? const Color(0xFFE54350) : Colors.transparent,
//                 width: 4,
//               ),
//             ),
//           ),
//           child: Center(
//             child: Text(
//               label,
//               style: GoogleFonts.manrope(
//                 fontSize: 18,
//                 fontWeight: FontWeight.w600,
//                 color: isSelected ? const Color(0xFFE54350) : const Color(0xFFA8B1C2),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildFormattedOverviewText(String text) {
//     // Split text into paragraphs
//     final paragraphs = text.split('\n\n');
    
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: paragraphs.asMap().entries.map((entry) {
//         final index = entry.key;
//         final paragraph = entry.value.trim();
        
//         if (paragraph.isEmpty) return const SizedBox.shrink();
        
//         // Pattern to match numbers, percentages, financial figures, and key metrics
//         final pattern = RegExp(
//           r'(\d+(?:\.\d+)?%|₹[\d,.]+(?:\s*(?:Cr|crore|lakh|L|K))?|\d+(?:\.\d+)?(?:\s*(?:Cr|crore|lakh|billion|million|L|K))|\d+(?:\.\d+)?x|\b(?:growth|increase|decrease|rise|fall)\b)',
//           caseSensitive: false,
//         );

//         final List<TextSpan> spans = [];
//         int lastMatchEnd = 0;

//         for (final match in pattern.allMatches(paragraph)) {
//           // Add regular text before the match
//           if (match.start > lastMatchEnd) {
//             spans.add(
//               TextSpan(
//                 text: paragraph.substring(lastMatchEnd, match.start),
//                 style: GoogleFonts.manrope(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w400,
//                   height: 1.8,
//                   letterSpacing: 0,
//                   color: const Color(0xFF3F4A4A),
//                 ),
//               ),
//             );
//           }

//           // Add bold green matched text (number/percentage/metric)
//           spans.add(
//             TextSpan(
//               text: match.group(0),
//               style: GoogleFonts.manrope(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w700,
//                 height: 1.8,
//                 letterSpacing: 0,
//                 color: const Color(0xFF007A5A),
//               ),
//             ),
//           );

//           lastMatchEnd = match.end;
//         }

//         // Add remaining text after the last match
//         if (lastMatchEnd < paragraph.length) {
//           spans.add(
//             TextSpan(
//               text: paragraph.substring(lastMatchEnd),
//               style: GoogleFonts.manrope(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w400,
//                 height: 1.8,
//                 letterSpacing: 0,
//                 color: const Color(0xFF3F4A4A),
//               ),
//             ),
//           );
//         }

//         return Padding(
//           padding: EdgeInsets.only(bottom: index < paragraphs.length - 1 ? 20 : 0),
//           child: RichText(
//             text: TextSpan(children: spans),
//           ),
//         );
//       }).toList(),
//     );
//   }

//   Widget _buildFormattedText(String text) {
//     // Split text into paragraphs
//     final paragraphs = text.split('\n\n');
    
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: paragraphs.asMap().entries.map((entry) {
//         final index = entry.key;
//         final paragraph = entry.value.trim();
        
//         if (paragraph.isEmpty) return const SizedBox.shrink();
        
//         // Pattern to match numbers, percentages, financial figures, and key metrics
//         final pattern = RegExp(
//           r'(₹[\d,.]+(?:\s*(?:Cr|crore|lakh|L|K))?|\d+(?:\.\d+)?%|\d+(?:\.\d+)?(?:\s*(?:Cr|crore|lakh|billion|million|L|K))|\d+(?:\.\d+)?x|\b(?:growth|increase|decrease|rise|fall|up|down)\s+(?:of|by)?\s*\d+(?:\.\d+)?%?)',
//           caseSensitive: false,
//         );

//         final List<TextSpan> spans = [];
//         int lastMatchEnd = 0;

//         for (final match in pattern.allMatches(paragraph)) {
//           // Add regular text before the match
//           if (match.start > lastMatchEnd) {
//             spans.add(
//               TextSpan(
//                 text: paragraph.substring(lastMatchEnd, match.start),
//                 style: GoogleFonts.manrope(
//                   fontSize: 14,
//                   fontWeight: FontWeight.w400,
//                   height: 28 / 14,
//                   letterSpacing: 0,
//                   color: const Color(0xFF191C1E),
//                 ),
//               ),
//             );
//           }

//           // Add bold matched text (number/percentage/metric)
//           spans.add(
//             TextSpan(
//               text: match.group(0),
//               style: GoogleFonts.manrope(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w700,
//                 height: 28 / 14,
//                 letterSpacing: 0,
//                 color: const Color(0xFF191C1E),
//               ),
//             ),
//           );

//           lastMatchEnd = match.end;
//         }

//         // Add remaining text after the last match
//         if (lastMatchEnd < paragraph.length) {
//           spans.add(
//             TextSpan(
//               text: paragraph.substring(lastMatchEnd),
//               style: GoogleFonts.manrope(
//                 fontSize: 14,
//                 fontWeight: FontWeight.w400,
//                 height: 28 / 14,
//                 letterSpacing: 0,
//                 color: const Color(0xFF191C1E),
//               ),
//             ),
//           );
//         }

//         return Padding(
//           padding: EdgeInsets.only(bottom: index < paragraphs.length - 1 ? 24 : 0),
//           child: RichText(
//             text: TextSpan(children: spans),
//           ),
//         );
//       }).toList(),
//     );
//   }

//   Widget _buildEventsTab() {
//     if (_isLoadingEvents) {
//       return const Center(child: CircularProgressIndicator());
//     }
//     if (_eventsError.isNotEmpty) {
//       return Center(child: Text(_eventsError, style: const TextStyle(color: Colors.red)));
//     }
//     if (_companyEvents.isEmpty) {
//       return const Center(child: Text('No events available for this company'));
//     }
//     return ListView.builder(
//       padding: const EdgeInsets.all(16),
//       itemCount: _companyEvents.length,
//       itemBuilder: (context, index) => _buildEventItem(_companyEvents[index]),
//     );
//   }

//   Widget _buildEventItem(Map<String, dynamic> event) {
//     final title = event["title"] ?? "No title";
//     final date = event["date"] ?? "";
//     final description = event["description"] ?? "";
//     final type = event["type"] ?? "Event";

//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: Colors.grey.shade200),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.06),
//             blurRadius: 8,
//             offset: const Offset(0, 2),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             decoration: BoxDecoration(
//               color: Colors.grey.shade50,
//               borderRadius: const BorderRadius.only(
//                 topLeft: Radius.circular(14),
//                 topRight: Radius.circular(14),
//               ),
//             ),
//             child: Row(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                   decoration: BoxDecoration(
//                     color: const Color(0xFFF05151).withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(20),
//                   ),
//                   child: Text(
//                     type,
//                     style: const TextStyle(
//                       fontSize: 12,
//                       fontWeight: FontWeight.w600,
//                       color: Color(0xFFF05151),
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
//                 const SizedBox(width: 6),
//                 Text(
//                   _formatDate(date),
//                   style: TextStyle(
//                     fontSize: 12,
//                     color: Colors.grey.shade600,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   title,
//                   style: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                     color: Color(0xFF2D3748),
//                   ),
//                 ),
//                 if (description.isNotEmpty) ...[
//                   const SizedBox(height: 12),
//                   Text(
//                     description,
//                     style: TextStyle(
//                       fontSize: 14,
//                       color: Colors.grey.shade800,
//                       height: 1.5,
//                     ),
//                   ),
//                 ],
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }


import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'home_screen.dart';
import 'chatbot_screen.dart';
import 'company_screen.dart';
import 'events_screen.dart';
import 'saved_screen.dart';
import 'profile_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'index_screen.dart';
import '../widgets/smooth_line_chart_painter.dart';
import '../widgets/financial_icons.dart';

class CompanyNewsScreen extends StatefulWidget {
  final String companyName;
  final String companySymbol;

  const CompanyNewsScreen({
    super.key,
    required this.companyName,
    required this.companySymbol,
  });

  @override
  State<CompanyNewsScreen> createState() => _CompanyNewsScreenState();
}

class _CompanyNewsScreenState extends State<CompanyNewsScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _news = [];
  Map<String, dynamic>? _stockData;
  Map<String, dynamic>? _aiOverview;
  Map<String, dynamic>? _aiInsight;
  List<Map<String, dynamic>> _companyEvents = [];
  bool _isLoading = false;
  bool _isLoadingStock = false;
  bool _isLoadingAI = false;
  bool _isLoadingInsight = false;
  bool _isLoadingEvents = false;
  String _error = '';
  String _stockError = '';
  String _aiError = '';
  String _insightError = '';
  String _eventsError = '';

  late TabController _tabController;
  int _selectedTabIndex = 0;
  int _bottomIndex = 1;

  List<Map<String, dynamic>> _chartData = [];
  bool _isLoadingChart = false;
  String _chartError = '';
  String _selectedTimeframe = '1W';


  final String _finedgeApiToken = dotenv.env['FINEDGE_API_TOKEN']!;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });


    _fetchStockData();
    _fetchCompanyNews();
    _fetchAIOverview();
    _fetchAIInsight();
    _fetchChartData('1W');
    _fetchCompanyEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // ALL FETCH METHODS — UNCHANGED
  // ─────────────────────────────────────────────────────────────

  Future<void> _fetchStockData() async {
    setState(() {
      _isLoadingStock = true;
      _stockError = '';
    });

    try {
      var symbol = widget.companySymbol.toUpperCase();
      if (symbol.endsWith('.NSE') || symbol.endsWith('.BSE')) {
        symbol = symbol.split('.').first;
      }

      int retries = 3;
      int delayMs = 1000;
      http.Response? quoteResponse;

      for (int i = 0; i < retries; i++) {
        try {
          quoteResponse = await http
              .get(
                Uri.parse("https://data.finedgeapi.com/api/v1/quote").replace(
                  queryParameters: {
                    'symbol': symbol,
                    'token': _finedgeApiToken
                  },
                ),
                headers: {'Accept': 'application/json'},
              )
              .timeout(const Duration(seconds: 10));

          if (quoteResponse.statusCode == 200) {
            break;
          } else if (quoteResponse.statusCode == 503 ||
              quoteResponse.statusCode == 429) {
            if (i < retries - 1) {
              await Future.delayed(Duration(milliseconds: delayMs));
              delayMs *= 2;
            }
          } else {
            break;
          }
        } catch (e) {
          if (i == retries - 1) rethrow;
          await Future.delayed(Duration(milliseconds: delayMs));
          delayMs *= 2;
        }
      }

      if (quoteResponse == null || quoteResponse.statusCode != 200) {
        setState(() {
          _stockError = quoteResponse?.statusCode == 503 ||
                  quoteResponse?.statusCode == 429
              ? "Rate limit exceeded. Please wait and try again."
              : "Failed to fetch quote data (${quoteResponse?.statusCode ?? 'timeout'})";
        });
        return;
      }

      final quoteJson = json.decode(quoteResponse.body);
      dynamic quoteData;
      if (quoteJson is Map) {
        quoteData = quoteJson[symbol] ??
            quoteJson[symbol.toLowerCase()] ??
            quoteJson['data'] ??
            quoteJson;
      } else {
        quoteData = quoteJson;
      }

      if (quoteData == null ||
          (quoteData is! Map && quoteData is! List)) {
        setState(() {
          _stockError = "Invalid data format for symbol: $symbol";
        });
        return;
      }

      if (quoteData is List && quoteData.isNotEmpty) {
        quoteData = quoteData.first;
      }

      final currentPrice = quoteData['current_price'] ??
          quoteData['last_price'] ??
          quoteData['ltp'] ??
          quoteData['close'] ??
          quoteData['lastPrice'];
      final high = quoteData['high_price'] ??
          quoteData['high'] ??
          quoteData['dayHigh'];
      final low =
          quoteData['low_price'] ?? quoteData['low'] ?? quoteData['dayLow'];
      final open = quoteData['open_price'] ??
          quoteData['open'] ??
          quoteData['openPrice'];
      final changePercent = quoteData['change'] ??
          quoteData['pChange'] ??
          quoteData['percentChange'] ??
          quoteData['changePct'];
      final volume =
          quoteData['volume'] ?? quoteData['totalTradedVolume'];

      double? changeValue;
      double? changePct;
      if (changePercent != null) {
        try {
          changePct = double.parse(
              changePercent.toString().replaceAll('%', '').trim());
          if (currentPrice != null && open != null) {
            changeValue = double.parse(currentPrice.toString()) -
                double.parse(open.toString());
          }
        } catch (e) {
          print('Error parsing change percent: $e');
        }
      }

      String? eps;
      String? peRatio;
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        final priceRatiosUrl = Uri.parse(
          "https://data.finedgeapi.com/api/v1/annual-price-ratios/$symbol",
        ).replace(queryParameters: {
          'token': _finedgeApiToken,
          'statement_type': 's',
        });
        final priceRatiosResponse = await http
            .get(priceRatiosUrl, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 10));
        if (priceRatiosResponse.statusCode == 200 &&
            priceRatiosResponse.body.isNotEmpty) {
          final ratiosData = json.decode(priceRatiosResponse.body);
          dynamic ratiosList = ratiosData['price_ratios'];
          if (ratiosList != null &&
              ratiosList is List &&
              ratiosList.isNotEmpty) {
            final latest = ratiosList.first;
            final peValue = latest['pe'] ??
                latest['priceToEarnings'] ??
                latest['PE'] ??
                latest['peRatio'] ??
                latest['priceEarningsRatio'];
            if (peValue != null) {
              peRatio =
                  double.parse(peValue.toString()).toStringAsFixed(2);
            }
          }
        }
      } catch (e) {
        print('ERROR fetching price ratios: $e');
      }

      String? revenue;
      String? ebitda;
      String? ebit;
      String? netProfit;
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        final financialsUrl = Uri.parse(
          "https://data.finedgeapi.com/api/v1/financials/$symbol",
        ).replace(queryParameters: {
          'token': _finedgeApiToken,
          'statement_type': 's',
          'statement_code': 'pl',
          'period': 'annual',
        });
        final financialsResponse = await http
            .get(financialsUrl, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 10));
        if (financialsResponse.statusCode == 200 &&
            financialsResponse.body.isNotEmpty) {
          final finData = json.decode(financialsResponse.body);
          dynamic financialsList;
          if (finData is Map) {
            financialsList =
                finData['financials'] ?? finData['data'] ?? finData['results'];
          } else if (finData is List) {
            financialsList = finData;
          }
          if (financialsList != null &&
              financialsList is List &&
              financialsList.isNotEmpty) {
            final latest = financialsList.first;
            final isBank = (latest.containsKey('interestEarned') &&
                    latest.containsKey('interestExpended')) ||
                (latest.containsKey('netInterestIncome')) ||
                (latest.containsKey('income') &&
                    !latest.containsKey('revenueFromOperations') &&
                    !latest.containsKey('costofGoodsSold'));
            if (isBank) {
              final totalIncome = latest['income'] ??
                  latest['totalIncome'] ??
                  latest['operatingIncome'];
              if (totalIncome != null) {
                revenue = (double.parse(totalIncome.toString()) / 10000000)
                    .toStringAsFixed(2);
              }
              final netIncome = latest['profitLossForThePeriod'] ??
                  latest['profitLossForPeriod'] ??
                  latest['netProfit'] ??
                  latest['profitAfterTax'];
              if (netIncome != null) {
                netProfit = (double.parse(netIncome.toString()) / 10000000)
                    .toStringAsFixed(2);
              }
              final operatingProfit = latest['profitLossBeforeTax'] ??
                  latest['profitBeforeTax'];
              if (operatingProfit != null) {
                ebit =
                    (double.parse(operatingProfit.toString()) / 10000000)
                        .toStringAsFixed(2);
              }
              ebitda = 'N/A (Bank)';
            } else {
              final totalRev = latest['revenueFromOperations'] ??
                  latest['totalRevenue'] ??
                  latest['revenue'] ??
                  latest['operatingRevenue'] ??
                  latest['netRevenue'] ??
                  latest['Revenue'] ??
                  latest['totalIncome'];
              if (totalRev != null) {
                revenue = (double.parse(totalRev.toString()) / 10000000)
                    .toStringAsFixed(2);
              }
              final netIncome = latest['profitLossForPeriod'] ??
                  latest['profitLossForThePeriod'] ??
                  latest['netIncome'] ??
                  latest['netProfit'] ??
                  latest['profitAfterTax'] ??
                  latest['Net Profit'] ??
                  latest['netIncomeAfterTax'];
              if (netIncome != null) {
                netProfit = (double.parse(netIncome.toString()) / 10000000)
                    .toStringAsFixed(2);
              }
              try {
                final pbt = latest['profitBeforeTax'];
                final finCosts = latest['financeCosts'];
                final depreciation = latest['depreciationAndAmortisation'];
                if (pbt != null && finCosts != null && depreciation != null) {
                  final ebitdaValue =
                      (double.parse(pbt.toString()) +
                              double.parse(finCosts.toString()) +
                              double.parse(depreciation.toString())) /
                          10000000;
                  ebitda = ebitdaValue.toStringAsFixed(2);
                }
              } catch (_) {}
              try {
                final pbt = latest['profitBeforeTax'];
                final finCosts = latest['financeCosts'];
                if (pbt != null && finCosts != null) {
                  final ebitValue =
                      (double.parse(pbt.toString()) +
                              double.parse(finCosts.toString())) /
                          10000000;
                  ebit = ebitValue.toStringAsFixed(2);
                }
              } catch (_) {}
            }
            final epsValue = latest['eps'] ??
                latest['earningsPerShare'] ??
                latest['EPS'] ??
                latest['basicEPS'];
            if (epsValue != null) {
              eps = double.parse(epsValue.toString()).toStringAsFixed(2);
            }
          }
        }
      } catch (e) {
        print('ERROR fetching financials: $e');
      }

      String? totalAssets;
      String? totalLiabilities;
      String? longTermDebt;
      String? shareholdersEquity;
      String? cashEquivalents;
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        final bsUrl = Uri.parse(
          "https://data.finedgeapi.com/api/v1/basic-financials/$symbol",
        ).replace(queryParameters: {
          'token': _finedgeApiToken,
          'statement_type': 's',
          'statement_code': 'bs',
        });
        final bsResponse = await http
            .get(bsUrl, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 10));
        if (bsResponse.statusCode == 200 && bsResponse.body.isNotEmpty) {
          final bsData = json.decode(bsResponse.body);
          dynamic bsList = bsData['ratios'];
          if (bsList != null && bsList is List && bsList.isNotEmpty) {
            final latest = bsList.first;
            final assets = latest['totalAssets'];
            if (assets != null) {
              totalAssets = (double.parse(assets.toString()) / 10000000)
                  .toStringAsFixed(2);
            }
            final liabilities = latest['totalLiabilities'];
            if (liabilities != null) {
              totalLiabilities =
                  (double.parse(liabilities.toString()) / 10000000)
                      .toStringAsFixed(2);
            }
            final debt =
                latest['longTermBorrowings'] ?? latest['totalDebt'];
            if (debt != null) {
              longTermDebt = (double.parse(debt.toString()) / 10000000)
                  .toStringAsFixed(2);
            }
            final equity = latest['totalEquity'];
            if (equity != null) {
              shareholdersEquity =
                  (double.parse(equity.toString()) / 10000000)
                      .toStringAsFixed(2);
            }
            final cash = latest['totalCash'];
            if (cash != null) {
              cashEquivalents = (double.parse(cash.toString()) / 10000000)
                  .toStringAsFixed(2);
            }
          }
        }
      } catch (e) {
        print('ERROR fetching balance sheet: $e');
      }

      String? operatingCashFlow;
      String? investingCashFlow;
      String? financingCashFlow;
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        final cfUrl = Uri.parse(
          "https://data.finedgeapi.com/api/v1/basic-financials/$symbol",
        ).replace(queryParameters: {
          'token': _finedgeApiToken,
          'statement_type': 's',
          'statement_code': 'cf',
        });
        final cfResponse = await http
            .get(cfUrl, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 10));
        if (cfResponse.statusCode == 200 && cfResponse.body.isNotEmpty) {
          final cfData = json.decode(cfResponse.body);
          dynamic cfList = cfData['ratios'];
          if (cfList != null && cfList is List && cfList.isNotEmpty) {
            final latest = cfList.first;
            final opCF = latest['operatingCashFlow'];
            if (opCF != null) {
              operatingCashFlow =
                  (double.parse(opCF.toString()) / 10000000)
                      .toStringAsFixed(2);
            }
            final invCF = latest['investingCashFlow'];
            if (invCF != null) {
              investingCashFlow =
                  (double.parse(invCF.toString()) / 10000000)
                      .toStringAsFixed(2);
            }
            final finCF = latest['financingCashFlow'];
            if (finCF != null) {
              financingCashFlow =
                  (double.parse(finCF.toString()) / 10000000)
                      .toStringAsFixed(2);
            }
          }
        }
      } catch (e) {
        print('ERROR fetching cash flow: $e');
      }

      String? pbRatio;
      String? psRatio;
      String? marketCap;
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        final ratiosUrl = Uri.parse(
          "https://data.finedgeapi.com/api/v1/annual-price-ratios/$symbol",
        ).replace(queryParameters: {
          'token': _finedgeApiToken,
          'statement_type': 's',
        });
        final ratiosResp = await http
            .get(ratiosUrl, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 10));
        if (ratiosResp.statusCode == 200 && ratiosResp.body.isNotEmpty) {
          final ratiosData = json.decode(ratiosResp.body);
          dynamic ratiosList = ratiosData['price_ratios'];
          if (ratiosList != null &&
              ratiosList is List &&
              ratiosList.isNotEmpty) {
            final latest = ratiosList.first;
            final pb =
                latest['pb'] ?? latest['priceToBook'] ?? latest['pbRatio'];
            if (pb != null) {
              pbRatio = double.parse(pb.toString()).toStringAsFixed(2);
            }
            final ps =
                latest['ps'] ?? latest['priceToSales'] ?? latest['psRatio'];
            if (ps != null) {
              psRatio = double.parse(ps.toString()).toStringAsFixed(2);
            }
            final mktCap =
                latest['marketCap'] ?? latest['market_cap'];
            if (mktCap != null) {
              marketCap =
                  (double.parse(mktCap.toString()) / 10000000)
                      .toStringAsFixed(2);
            }
          }
        }
      } catch (e) {
        print('ERROR fetching additional ratios: $e');
      }

      setState(() {
        _stockData = {
          'Company Name': widget.companyName,
          'Symbol': symbol,
          'Current Price': currentPrice?.toString() ?? 'N/A',
          'High': high?.toString() ?? 'N/A',
          'Low': low?.toString() ?? 'N/A',
          'Open': open?.toString() ?? 'N/A',
          'Change Value': changeValue?.toStringAsFixed(2) ?? 'N/A',
          'Change Percent': changePct?.toStringAsFixed(2) ?? 'N/A',
          'Volume': volume?.toString() ?? 'N/A',
          'Revenue': revenue ?? 'N/A',
          'EBITDA': ebitda ?? 'N/A',
          'EBIT': ebit ?? 'N/A',
          'Net Profit': netProfit ?? 'N/A',
          'EPS': eps ?? 'N/A',
          'Stock P/E': peRatio ?? 'N/A',
          'Total Assets': totalAssets ?? 'N/A',
          'Total Liabilities': totalLiabilities ?? 'N/A',
          'Long-Term Debt': longTermDebt ?? 'N/A',
          'Shareholders Equity': shareholdersEquity ?? 'N/A',
          'Operating Cash Flow': operatingCashFlow ?? 'N/A',
          'Investing Cash Flow': investingCashFlow ?? 'N/A',
          'Financing Cash Flow': financingCashFlow ?? 'N/A',
          'Cash & Equivalents': cashEquivalents ?? 'N/A',
          'P/B Ratio': pbRatio ?? 'N/A',
          'P/S Ratio': psRatio ?? 'N/A',
          'Market Cap': marketCap ?? 'N/A',
        };
        _stockError = '';
      });
    } catch (e, stackTrace) {
      print('FATAL ERROR: $e\n$stackTrace');
      setState(() {
        _stockError = "Stock data fetch failed: $e";
      });
    }

    setState(() => _isLoadingStock = false);
  }

  Future<void> _fetchCompanyNews() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final encodedName = Uri.encodeComponent(widget.companyName);
      final resp = await http
          .get(Uri.parse(
              "http://51.20.136.45:5000/api/filtered-news/company/$encodedName"));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        setState(() {
          _news = (data as List).cast<Map<String, dynamic>>();
        });
      } else {
        setState(() {
          _error =
              "Failed to fetch news\nStatus: ${resp.statusCode}\nError: ${resp.body}";
        });
      }
    } catch (e) {
      setState(() {
        _error = "DB fetch failed: $e";
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _fetchAIOverview() async {
    setState(() {
      _isLoadingAI = true;
      _aiError = '';
    });
    try {
      var symbol = widget.companySymbol.toUpperCase();
      if (symbol.endsWith('.NSE') || symbol.endsWith('.BSE')) {
        symbol = symbol.split('.').first;
      }
      final url = Uri.parse(
        'http://51.20.136.45:5001/api/ai-overview/$symbol',
      ).replace(queryParameters: {
        'company_name': widget.companyName,
        'v': '5',
      });
      final resp =
          await http.get(url).timeout(const Duration(seconds: 150));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['success'] == true) {
          setState(() {
            _aiOverview = {
              'overview': data['overview'],
              'generated_at': data['generated_at'],
              'company_name': data['company_name'],
              'symbol': data['symbol'],
            };
          });
        } else {
          setState(() {
            _aiError = data['error'] ?? "Failed to generate AI overview";
          });
        }
      } else {
        setState(() {
          _aiError = "Failed to fetch AI overview (${resp.statusCode})";
        });
      }
    } catch (e) {
      setState(() {
        _aiError = "Connection failed: $e";
        _aiOverview = null;
      });
    }
    setState(() => _isLoadingAI = false);
  }

  Future<void> _fetchAIInsight() async {
    setState(() {
      _isLoadingInsight = true;
      _insightError = '';
    });
    try {
      var symbol = widget.companySymbol.toUpperCase();
      if (symbol.endsWith('.NSE') || symbol.endsWith('.BSE')) {
        symbol = symbol.split('.').first;
      }
      final url = Uri.parse(
        'http://51.20.136.45:5001/api/ai-insight/$symbol',
      ).replace(queryParameters: {
        'company_name': widget.companyName,
        'v': '5',
      });
      final resp =
          await http.get(url).timeout(const Duration(seconds: 150));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        if (data['success'] == true) {
          setState(() {
            _aiInsight = {
              'insight': data['insight'],
              'generated_at': data['generated_at'],
            };
          });
        } else {
          setState(() {
            _insightError =
                data['error'] ?? "Failed to generate AI insight";
          });
        }
      } else {
        setState(() {
          _insightError =
              "Failed to fetch AI insight (${resp.statusCode})";
        });
      }
    } catch (e) {
      setState(() {
        _insightError = "Connection failed: $e";
      });
    }
    setState(() => _isLoadingInsight = false);
  }

  Future<void> _fetchCompanyEvents() async {
    setState(() {
      _isLoadingEvents = true;
      _eventsError = '';
    });
    try {
      final encodedName = Uri.encodeComponent(widget.companyName);
      final resp = await http.get(Uri.parse(
          "http://51.20.136.45:5000/api/events/company/$encodedName"));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        setState(() {
          _companyEvents =
              (data as List).cast<Map<String, dynamic>>();
        });
      } else {
        setState(() {
          _eventsError =
              "Failed to fetch events (${resp.statusCode})";
        });
      }
    } catch (e) {
      setState(() {
        _eventsError = "Failed to load events: $e";
      });
    }
    setState(() => _isLoadingEvents = false);
  }

  Future<void> _fetchChartData(String timeframe) async {
    setState(() {
      _isLoadingChart = true;
      _chartError = '';
      _selectedTimeframe = timeframe;
    });

    try {
      var symbol = widget.companySymbol.toUpperCase();
      if (symbol.endsWith('.NSE') || symbol.endsWith('.BSE')) {
        symbol = symbol.split('.').first;
      }

      String range, interval;
      switch (timeframe) {
        case '1D':
          range = '1d';
          interval = '5m';
          break;
        case '1W':
          range = '7d';
          interval = '1d';
          break;
        case '1Y':
          range = '1y';
          interval = '1wk';
          break;
        case '5Y':
          range = '5y';
          interval = '1mo';
          break;
        case 'ALL':
          range = 'max';
          interval = '1mo';
          break;
        case '1M':
        default:
          range = '1mo';
          interval = '1d';
      }

      final url = Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/$symbol.NS',
      ).replace(queryParameters: {'range': range, 'interval': interval});

      final response =
          await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['chart']?['result'] == null ||
            data['chart']['result'].isEmpty) {
          setState(() {
            _chartError = 'No chart data available';
            _chartData = [];
          });
          return;
        }

        final result = data['chart']['result'][0];
        final timestamps = result['timestamp'] as List?;
        final quote = result['indicators']?['quote']?[0];

        if (timestamps == null || quote == null) {
          setState(() {
            _chartError = 'Invalid chart data format';
            _chartData = [];
          });
          return;
        }

        final closes = quote['close'] as List?;
        if (closes == null) {
          setState(() {
            _chartError = 'Missing close data';
            _chartData = [];
          });
          return;
        }

        List<Map<String, dynamic>> chartData = [];
        for (int i = 0; i < timestamps.length; i++) {
          if (closes[i] != null) {
            chartData.add({
              'time': timestamps[i],
              'value': (closes[i] as num).toDouble(),
            });
          }
        }

        setState(() {
          _chartData = chartData;
          _chartError = '';
        });

       
      } else {
        setState(() {
          _chartError =
              'Failed to fetch chart data (${response.statusCode})';
          _chartData = [];
        });
      }
    } catch (e) {
      setState(() {
        _chartError = 'Chart not available';
        _chartData = [];
      });
    }

    setState(() => _isLoadingChart = false);
  }

  

  // ─── LINE CHART HTML (matches Image 2 style) ───────────────
  String _getLineChartHTML() {
    final jsonData = json.encode(_chartData);
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <script src="https://unpkg.com/lightweight-charts@4.1.0/dist/lightweight-charts.standalone.production.js"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { overflow: hidden; background: transparent; }
    #chart { width: 100vw; height: 100vh; }
  </style>
</head>
<body>
  <div id="chart"></div>
  <script>
    try {
      const chartContainer = document.getElementById('chart');
      const chart = LightweightCharts.createChart(chartContainer, {
        width: chartContainer.clientWidth,
        height: chartContainer.clientHeight,
        layout: {
          background: { type: 'solid', color: 'transparent' },
          textColor: '#888',
        },
        grid: {
          vertLines: { visible: false },
          horzLines: { color: 'rgba(0,0,0,0.05)' },
        },
        crosshair: { mode: LightweightCharts.CrosshairMode.Magnet },
        rightPriceScale: {
          borderVisible: false,
          scaleMargins: { top: 0.1, bottom: 0.1 },
        },
        timeScale: {
          borderVisible: false,
          timeVisible: true,
          secondsVisible: false,
        },
        handleScroll: false,
        handleScale: false,
      });

      const lineSeries = chart.addAreaSeries({
        lineColor: '#1B7A5A',
        topColor: 'rgba(27,122,90,0.18)',
        bottomColor: 'rgba(27,122,90,0.0)',
        lineWidth: 2.5,
        crosshairMarkerVisible: true,
        crosshairMarkerRadius: 5,
        crosshairMarkerBorderColor: '#fff',
        crosshairMarkerBackgroundColor: '#1B7A5A',
      });

      window.chart = chart;
      window.lineSeries = lineSeries;

      const data = $jsonData;
      if (data && data.length > 0) {
        lineSeries.setData(data);
        chart.timeScale().fitContent();
      }

      window.addEventListener('resize', () => {
        chart.applyOptions({
          width: chartContainer.clientWidth,
          height: chartContainer.clientHeight,
        });
      });
    } catch (e) {
      console.error('Chart error:', e);
    }
  </script>
</body>
</html>
    ''';
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return "Date not available";
    try {
      final date =
          DateFormat("EEEE, MMM dd, yyyy HH:mm:ss").parse(dateString);
      return DateFormat.yMMMd().add_jm().format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _parseIndianNumber(String? value) {
    if (value == null || value.isEmpty) return 'N/A';
    return value.replaceAll(',', '');
  }

  String _formatMarketCap() {
    final marketCap = _stockData?['Market Cap'];
    if (marketCap == null || marketCap.toString() == 'N/A') return 'N/A';
    try {
      final value =
          double.parse(_parseIndianNumber(marketCap.toString()));
      if (value >= 100000)
        return '₹${(value / 100000).toStringAsFixed(2)}L Cr';
      if (value >= 1000)
        return '₹${(value / 1000).toStringAsFixed(2)}K Cr';
      return '₹${value.toStringAsFixed(2)} Cr';
    } catch (e) {
      return '₹${marketCap.toString()} Cr';
    }
  }

  /// Format price with commas (e.g. 1043.15 → 1,043.15)
  String _formatPrice(String raw) {
    try {
      final value = double.parse(raw);
      final formatter = NumberFormat('#,##,##0.##', 'en_IN');
      return formatter.format(value);
    } catch (_) {
      return raw;
    }
  }

  String formatValue(String val) {
    if (val == 'N/A' || val == 'N/A (Bank)') return val;
    try {
      final numVal = double.parse(val);
      if (numVal >= 100000) return '₹${(numVal / 100000).toStringAsFixed(2)}L Cr';
      if (numVal >= 10000) return '₹${numVal.toStringAsFixed(0)} Cr';
      if (numVal >= 1000) return '₹${(numVal / 1000).toStringAsFixed(2)}K Cr';
      if (numVal < 100) return numVal.toStringAsFixed(2);
      return '₹${numVal.toStringAsFixed(2)} Cr';
    } catch (e) {
      return val;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // CHART WIDGET
  // ─────────────────────────────────────────────────────────────

  Widget _buildChartWidget() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Chart area ──
          Container(
            height: 340,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF8F4),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Stack(
              children: [
                // WebView / loading / error
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: _isLoadingChart
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF1B7A5A),
                            strokeWidth: 2,
                          ),
                        )
                      : _chartError.isNotEmpty
                          ? Center(
                              child: Text(
                                _chartError,
                                style: GoogleFonts.manrope(
                                  fontSize: 13,
                                  color: const Color(0xFF5A5D72),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : _chartData.isEmpty
                              ? Center(
                                  child: Text(
                                    'No chart data available',
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      color: const Color(0xFF5A5D72),
                                    ),
                                  ),
                                )
                              : CustomPaint(
  size: const Size(double.infinity, 340),
  painter: SmoothLineChartPainter(
    chartData: _chartData,
  ),
)
                ),
                // ── Floating CURRENT badge ──
                if (_stockData != null)
                  Positioned(
                    top: 24,
                    right: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.07),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'CURRENT',
                            style: GoogleFonts.manrope(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF8A8F9E),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${_formatPrice(_stockData!['Current Price'] ?? '0')}',
                            style: GoogleFonts.manrope(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1B7A5A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Timeframe selector ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: ['1D', '1W', '1M', '1Y', '5Y', 'ALL']
                  .map((tf) => _buildTimeframeButton(tf))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeframeButton(String timeframe) {
    final isSelected = _selectedTimeframe == timeframe;
    return Expanded(
      child: GestureDetector(
        onTap: () => _fetchChartData(timeframe),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              timeframe,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF1B7A5A)
                    : const Color(0xFF8A8F9E),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // OVERVIEW TAB
  // ─────────────────────────────────────────────────────────────

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _buildChartWidget(),
          const SizedBox(height: 20),

          // ── AI Overview card ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 20,
                      color: Color(0xFFE54350),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI Overview',
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFE54350),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Body
                _isLoadingAI
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                              color: Color(0xFFE54350)),
                        ),
                      )
                    : _aiError.isNotEmpty && _aiOverview == null
                        ? Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3F3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Color(0xFFE54350), size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _aiError,
                                    style: GoogleFonts.manrope(
                                      fontSize: 13,
                                      color: const Color(0xFFE54350),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _buildFormattedOverviewText(
                            _aiOverview?['overview'] ??
                                'Unable to generate overview. Please try again later.',
                          ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FINANCIALS TAB — UNCHANGED LOGIC, minor style polish
  // ─────────────────────────────────────────────────────────────

  Widget _buildFinancialsTab() {
    if (_isLoadingStock) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_stockError.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(_stockError,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center),
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFinancialSection(
            title: 'INCOME STATEMENT (ANNUAL)',
            subtitle: 'Scale, profitability, and earnings strength',
            icon: const InfoIcon(size: 22),
            rows: [
              _buildFundamentalRow('Revenue', _stockData?['Revenue'] ?? 'N/A',
                  'EBITDA', _stockData?['EBITDA'] ?? 'N/A'),
              _buildFundamentalRow('EBIT', _stockData?['EBIT'] ?? 'N/A',
                  'Net Profit', _stockData?['Net Profit'] ?? 'N/A'),
              _buildFundamentalRow('EPS', _stockData?['EPS'] ?? 'N/A',
                  'P/E Ratio', _stockData?['Stock P/E'] ?? 'N/A'),
            ],
          ),
          _buildFinancialSection(
            title: 'BALANCE SHEET (LATEST ANNUAL)',
            subtitle: 'Snapshot of financial position',
            icon: const WalletIcon(size: 22),
            rows: [
              _buildFundamentalRow(
                  'Total Assets',
                  _stockData?['Total Assets'] ?? 'N/A',
                  'Total Liabilities',
                  _stockData?['Total Liabilities'] ?? 'N/A'),
              _buildFundamentalRow(
                  'Long-Term Debt',
                  _stockData?['Long-Term Debt'] ?? 'N/A',
                  'Cash & Equivalents',
                  _stockData?['Cash & Equivalents'] ?? 'N/A'),
              _buildFundamentalRow(
                  'Shareholders\' Equity',
                  _stockData?['Shareholders Equity'] ?? 'N/A',
                  '',
                  ''),
            ],
          ),
          _buildFinancialSection(
            title: 'CASH FLOW STATEMENT (ANNUAL)',
            subtitle: 'Cash generation and sustainability',
            icon: const CurrencyIcon(size: 22),
            rows: [
              _buildFundamentalRow(
                  'Operating Cash Flow',
                  _stockData?['Operating Cash Flow'] ?? 'N/A',
                  'Investing Cash Flow',
                  _stockData?['Investing Cash Flow'] ?? 'N/A'),
              _buildFundamentalRow(
                  'Financing Cash Flow',
                  _stockData?['Financing Cash Flow'] ?? 'N/A',
                  'Free Cash Flow',
                  'N/A'),
            ],
          ),
          Container(
            margin:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VALUATION & RETURNS',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Text('Is the stock reasonably valued?',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildValuationChip(
                        'P/E', _stockData?['Stock P/E'] ?? 'N/A'),
                    _buildValuationChip(
                        'P/B', _stockData?['P/B Ratio'] ?? 'N/A'),
                    _buildValuationChip(
                        'P/S', _stockData?['P/S Ratio'] ?? 'N/A'),
                    _buildValuationChip('Market Cap', _formatMarketCap()),
                  ],
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(
                left: 16, right: 16, top: 8, bottom: 32),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 22, color: Color(0xFFE54350)),
                    const SizedBox(width: 10),
                    Text(
                      'AI INSIGHT',
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF191C1E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _isLoadingInsight
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                              color: Color(0xFFE54350)),
                        ),
                      )
                    : _insightError.isNotEmpty && _aiInsight == null
                        ? Text(_insightError,
                            style: GoogleFonts.manrope(
                                fontSize: 14,
                                color: const Color(0xFFA0A0A0)))
                        : _buildFormattedText(
                            _aiInsight?['insight'] ??
                                'AI insight is limited due to incomplete financial data availability.',
                          ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSection({
    required String title,
    required String subtitle,
    required List<Widget> rows,
    Widget? icon,
  }) {
    return Container(
      margin:
          const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: const Color(0xFF191C1E))),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFFA0A0A0))),
                  ],
                ),
              ),
              if (icon != null) icon,
            ],
          ),
          const SizedBox(height: 16),
          ...rows
              .map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: r,
                  ))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildValuationChip(String label, String value) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748))),
        ],
      ),
    );
  }

  Widget _buildFundamentalRow(
      String label1, String value1, String label2, String value2) {
    String formattedValue1;
    if (label1 == 'EPS' || label1 == 'P/E Ratio') {
      formattedValue1 = value1 == 'N/A' ? value1 : '₹$value1';
    } else {
      formattedValue1 = formatValue(value1);
    }
    String formattedValue2;
    if (label2 == 'EPS' || label2 == 'P/E Ratio') {
      formattedValue2 = value2 == 'N/A'
          ? value2
          : value2.endsWith('x')
              ? value2
              : '${value2}x';
    } else {
      formattedValue2 = formatValue(value2);
    }

    if (label2.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label1,
              style: TextStyle(
                  fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          Text(formattedValue1,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label1,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Text(formattedValue1,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label2,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Text(formattedValue2,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // NEWS TAB
  // ─────────────────────────────────────────────────────────────

  Widget _buildNewsTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty)
      return Center(
          child:
              Text(_error, style: const TextStyle(color: Colors.red)));
    if (_news.isEmpty)
      return const Center(child: Text('No news available'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _news.length,
      itemBuilder: (context, index) => _buildNewsItem(_news[index]),
    );
  }

  Widget _buildNewsItem(Map<String, dynamic> article) {
    final headline = article["Headline"] ?? "No headline";
    final publishedAt = article["PublishedAt"] ?? "";
    final summary = article["summary"] ?? "";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(_formatDate(publishedAt),
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748))),
                if (summary.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Summary",
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFEA6B6B))),
                        const SizedBox(height: 6),
                        Text(summary,
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade800,
                                height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // EVENTS TAB
  // ─────────────────────────────────────────────────────────────

  Widget _buildEventsTab() {
    if (_isLoadingEvents)
      return const Center(child: CircularProgressIndicator());
    if (_eventsError.isNotEmpty)
      return Center(
          child: Text(_eventsError,
              style: const TextStyle(color: Colors.red)));
    if (_companyEvents.isEmpty)
      return const Center(
          child: Text('No events available for this company'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _companyEvents.length,
      itemBuilder: (context, index) =>
          _buildEventItem(_companyEvents[index]),
    );
  }

  Widget _buildEventItem(Map<String, dynamic> event) {
    final title = event["title"] ?? "No title";
    final date = event["date"] ?? "";
    final description = event["description"] ?? "";
    final type = event["type"] ?? "Event";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFF05151).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(type,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF05151))),
                ),
                const SizedBox(width: 8),
                Icon(Icons.calendar_today,
                    size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(_formatDate(date),
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748))),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(description,
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade800,
                          height: 1.5)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BOTTOM NAV HELPER
  // ─────────────────────────────────────────────────────────────

  BottomNavigationBarItem _navItem({
    required String label,
    required String active,
    required String inactive,
    required int index,
  }) {
    final bool selected = _bottomIndex == index;
    return BottomNavigationBarItem(
      icon: SvgPicture.asset(selected ? active : inactive, height: 22),
      label: label,
      tooltip: label,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MAIN BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final currentPrice =
        _stockData?['Current Price']?.toString() ?? '0.00';
    final changeValue =
        _stockData?['Change Value']?.toString() ?? '0';
    final changePct =
        _stockData?['Change Percent']?.toString() ?? '0';
    final bool isPositive = !changeValue.startsWith('-');

    // Format change badge: "+2.15 (0.11%)"
    String changeBadge;
    try {
      final cv = double.parse(changeValue);
      final cp = double.parse(changePct);
      changeBadge =
          '${cv >= 0 ? '+' : ''}${cv.toStringAsFixed(2)} (${cp.abs().toStringAsFixed(2)}%)';
    } catch (_) {
      changeBadge = '${isPositive ? '+' : ''}$changePct%';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back + Company Name
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F0),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.arrow_back,
                              color: Color(0xFFE54350),
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.companyName,
                          style: GoogleFonts.manrope(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF191C1E),
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Price row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Rs. ₹${_formatPrice(currentPrice)}',
                        style: GoogleFonts.manrope(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF191C1E),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Change badge — outlined pill style
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: isPositive
                              ? const Color(0xFFEAF7F1)
                              : const Color(0xFFFFF0F0),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isPositive
                                ? const Color(0xFF1B7A5A)
                                : const Color(0xFFE54350),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          changeBadge,
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isPositive
                                ? const Color(0xFF1B7A5A)
                                : const Color(0xFFE54350),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Tabs ──
                  Row(
                    children: [
                      _buildTabItem('OVERVIEW', 0),
                      _buildTabItem('FINANCIAL', 1),
                      _buildTabItem('NEWS', 2),
                      _buildTabItem('EVENTS', 3),
                    ],
                  ),
                ],
              ),
            ),

            // ── Tab content ─────────────────────────────────────
            Expanded(
              child: Container(
                color: const Color(0xFFF5F6F8),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildFinancialsTab(),
                    _buildNewsTab(),
                    _buildEventsTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // ── Bottom Nav ──────────────────────────────────────────
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
          selectedItemColor: const Color(0xFFEA6B6B),
          unselectedItemColor: Colors.black54,
          showUnselectedLabels: true,
          selectedLabelStyle: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.2),
          unselectedLabelStyle: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              height: 1.2),
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
            _navItem(
                label: "News",
                active: 'assets/icons/News Red.svg',
                inactive: 'assets/icons/News.svg',
                index: 0),
            _navItem(
                label: "Index",
                active: 'assets/icons/Index red.svg',
                inactive: 'assets/icons/Index.svg',
                index: 1),
            _navItem(
                label: "Ask AI",
                active: 'assets/icons/Ask AI Red.svg',
                inactive: 'assets/icons/Ask AI.svg',
                index: 2),
            _navItem(
                label: "Events",
                active: 'assets/icons/Calender Red.svg',
                inactive: 'assets/icons/Calender.svg',
                index: 3),
            _navItem(
                label: "Saved",
                active: 'assets/icons/Save red.svg',
                inactive: 'assets/icons/Save.svg',
                index: 4),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB ITEM
  // ─────────────────────────────────────────────────────────────

  Widget _buildTabItem(String label, int index) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => _tabController.animateTo(index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
                color: isSelected ? const Color(0xFFE54350) : const Color(0xFFA8B1C2),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 4,
              width: label.length * 9.0,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE54350) : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FORMATTED TEXT BUILDERS
  // ─────────────────────────────────────────────────────────────

  Widget _buildFormattedOverviewText(String text) {
    final paragraphs = text.split('\n\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.asMap().entries.map((entry) {
        final index = entry.key;
        final paragraph = entry.value.trim();
        if (paragraph.isEmpty) return const SizedBox.shrink();

        final pattern = RegExp(
          r'(\d+(?:\.\d+)?%|₹[\d,.]+(?:\s*(?:Cr|crore|lakh|L|K))?|\d+(?:\.\d+)?(?:\s*(?:Cr|crore|lakh|billion|million|L|K))|\d+(?:\.\d+)?x|\b(?:growth|increase|decrease|rise|fall)\b)',
          caseSensitive: false,
        );

        final List<TextSpan> spans = [];
        int lastMatchEnd = 0;

        for (final match in pattern.allMatches(paragraph)) {
          if (match.start > lastMatchEnd) {
            spans.add(TextSpan(
              text: paragraph.substring(lastMatchEnd, match.start),
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.75,
                color: const Color(0xFF3F4A4A),
              ),
            ));
          }
          spans.add(TextSpan(
            text: match.group(0),
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.75,
              color: const Color(0xFF1B7A5A),
            ),
          ));
          lastMatchEnd = match.end;
        }

        if (lastMatchEnd < paragraph.length) {
          spans.add(TextSpan(
            text: paragraph.substring(lastMatchEnd),
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.75,
              color: const Color(0xFF3F4A4A),
            ),
          ));
        }

        return Padding(
          padding: EdgeInsets.only(
              bottom: index < paragraphs.length - 1 ? 16 : 0),
          child: RichText(text: TextSpan(children: spans)),
        );
      }).toList(),
    );
  }

  Widget _buildFormattedText(String text) {
    final paragraphs = text.split('\n\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: paragraphs.asMap().entries.map((entry) {
        final index = entry.key;
        final paragraph = entry.value.trim();
        if (paragraph.isEmpty) return const SizedBox.shrink();

        final pattern = RegExp(
          r'(₹[\d,.]+(?:\s*(?:Cr|crore|lakh|L|K))?|\d+(?:\.\d+)?%|\d+(?:\.\d+)?(?:\s*(?:Cr|crore|lakh|billion|million|L|K))|\d+(?:\.\d+)?x|\b(?:growth|increase|decrease|rise|fall|up|down)\s+(?:of|by)?\s*\d+(?:\.\d+)?%?)',
          caseSensitive: false,
        );

        final List<TextSpan> spans = [];
        int lastMatchEnd = 0;

        for (final match in pattern.allMatches(paragraph)) {
          if (match.start > lastMatchEnd) {
            spans.add(TextSpan(
              text: paragraph.substring(lastMatchEnd, match.start),
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 2.0,
                color: const Color(0xFF191C1E),
              ),
            ));
          }
          spans.add(TextSpan(
            text: match.group(0),
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 2.0,
              color: const Color(0xFF191C1E),
            ),
          ));
          lastMatchEnd = match.end;
        }

        if (lastMatchEnd < paragraph.length) {
          spans.add(TextSpan(
            text: paragraph.substring(lastMatchEnd),
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 2.0,
              color: const Color(0xFF191C1E),
            ),
          ));
        }

        return Padding(
          padding: EdgeInsets.only(
              bottom: index < paragraphs.length - 1 ? 20 : 0),
          child: RichText(text: TextSpan(children: spans)),
        );
      }).toList(),
    );
  }
}
