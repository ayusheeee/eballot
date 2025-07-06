import 'package:flutter/material.dart';
import 'dart:io';
// import 'dart:typed_data'; // Removed unnecessary import
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';


class ProfileData {
  static String userName = '';
  static String userLocation = '';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-Ballot',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        brightness: Brightness.dark,
      ),
      themeMode: _themeMode,
      home: MainNavigation(
        onToggleTheme: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final VoidCallback? onToggleTheme;
  final bool isDarkMode;
  const MainNavigation({super.key, this.onToggleTheme, this.isDarkMode = false});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  static const List<String> _validVoterIds = ['VOTE123', 'VOTE456'];

  final TextEditingController _voterIdController = TextEditingController();
  String? _voteMessage;
  Color? _voteMessageColor;

  List<Widget> _buildPages() {
    return [
      HomePage(),
      CandidateFirestoreSearchPage(),
      VotePage(
        onVerify: _onVerify,
        voterIdController: _voterIdController,
        voteMessage: _voteMessage,
        voteMessageColor: _voteMessageColor,
      ),
      SocialPage(),
      ProfilePage(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _onVerify() {
    final id = _voterIdController.text.trim();
    setState(() {
      if (_validVoterIds.contains(id)) {
        _voteMessage = 'Verified!';
        _voteMessageColor = Colors.green;
      } else {
        _voteMessage = 'Invalid Voter ID';
        _voteMessageColor = Colors.red;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          ['Home', 'Search', 'Vote', 'Social', 'Profile'][_selectedIndex],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF8E24AA), // Soft purple
                Color(0xFF1976D2), // Deep blue
              ],
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: widget.isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: _buildPages()[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.how_to_vote),
            label: 'Vote',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Social',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        onTap: _onItemTapped,
      ),
    );
  }
}

// Home Page
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final List<Map<String, String>> electionUpdates = const [
    {
      'title': 'Presidential Election 2024',
      'description': 'Voting starts on Nov 5th. Make sure to check your registration status.',
      'date': 'Nov 1, 2025',
    },
    {
      'title': 'Local Council Results',
      'description': 'Results for the local council elections are now available online.',
      'date': 'Oct 30, 2025',
    },
    {
      'title': 'New Voting Guidelines',
      'description': 'Read about the updated guidelines for absentee ballots.',
      'date': 'Oct 28, 2025',
    },
    {
      'title': 'Debate Schedule Announced',
      'description': 'The official debate schedule for candidates has been released.',
      'date': 'Oct 20, 2025',
    },
    {
      'title': 'Voter Education Drive',
      'description': 'Join our voter education sessions happening throughout October.',
      'date': 'Oct 15, 2025',
    },
  ];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<double> _opacities = [];
  bool _showBanner = true;

  // Poll of the Day state
  final String _pollQuestion = 'Should voting be mandatory?';
  final List<String> _pollOptions = ['Yes', 'No', 'Not Sure'];
  String? _selectedPollOption;
  bool _hasVoted = false;

  // In _HomePageState, add state for hovered card and hovered action button
  int? _hoveredCardIndex;
  int? _hoveredActionIndex;

  final Map<String, List<Map<String, String>>> districtUpdates = {
    'Springfield': [
      {
        'title': 'Springfield Water Supply Notice',
        'description': 'Water supply will be interrupted on Nov 6th for maintenance.',
        'date': 'Nov 3, 2025',
      },
      {
        'title': 'Local Park Renovation',
        'description': 'Renovation of Central Park starts next week.',
        'date': 'Nov 2, 2025',
      },
    ],
    'Shelbyville': [
      {
        'title': 'Shelbyville Road Closures',
        'description': 'Main Street closed for parade on Nov 7th.',
        'date': 'Nov 4, 2025',
      },
    ],
  };

  List<Map<String, String>> get _filteredUpdates {
    if (_searchQuery.isEmpty) return electionUpdates;
    return electionUpdates.where((update) {
      final title = update['title']?.toLowerCase() ?? '';
      final desc = update['description']?.toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      return title.contains(query) || desc.contains(query);
    }).toList();
  }

  DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _opacities = List.filled(electionUpdates.length, 0.0);
    _fadeInCards();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  void _fadeInCards() async {
    for (int i = 0; i < electionUpdates.length; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) {
        setState(() {
          _opacities[i] = 1.0;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String get formattedDateTime {
    return DateFormat('EEEE, MMMM d, y — hh:mm a').format(_now);
  }

  void _showQuickActionDialog(String title, String message, {List<Map<String, String>>? faqs}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: faqs == null
            ? Text(message)
            : SizedBox(
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: faqs.length,
                  separatorBuilder: (context, i) => const Divider(height: 24),
                  itemBuilder: (context, i) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        faqs[i]['q']!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(faqs[i]['a']!),
                    ],
                  ),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      children: [
        // Gradient background with decorative shapes
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surface,
                colorScheme.surface,
              ],
            ),
          ),
        ),
        // Decorative circles
        Positioned(
          top: -40,
          left: -40,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withOpacity(0.08),
            ),
          ),
        ),
        Positioned(
          bottom: 60,
          right: -30,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.secondary.withOpacity(0.07),
            ),
          ),
        ),
        // Main content
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ProfileData.userName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                    child: Text(
                      'Welcome, ${ProfileData.userName}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                if (_showBanner)
                  MaterialBanner(
                    backgroundColor: colorScheme.secondary.withOpacity(0.1),
                    content: Text(
                      '🛑 Voting Deadline Tomorrow – Nov 4th',
                      style: TextStyle(
                        color: colorScheme.error,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showBanner = false;
                          });
                        },
                        child: Text('DISMISS', style: TextStyle(color: colorScheme.error)),
                      ),
                    ],
                  ),
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    'Latest Election Updates',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    formattedDateTime,
                    style: TextStyle(
                      fontSize: 15,
                      color: colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search updates...',
                      prefixIcon: Icon(Icons.search, color: colorScheme.primary),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      ...[0, 1, 2].map((i) {
                        final isHovered = _hoveredActionIndex == i;
                        final buttonData = [
                          {
                            'label': 'Check Registration',
                            'icon': Icons.how_to_reg,
                            'onPressed': () {
                              _showQuickActionDialog('Check Registration', 'Here you can check your voter registration status. (Feature coming soon)');
                            },
                          },
                          {
                            'label': 'Election FAQs',
                            'icon': Icons.help_outline,
                            'onPressed': () {
                              _showQuickActionDialog(
                                'Election FAQs',
                                '',
                                faqs: [
                                  {'q': 'What is E-Ballot?', 'a': 'E-Ballot is a secure online voting platform for modern elections.'},
                                  {'q': 'How do I register to vote?', 'a': 'You can register through the official government portal or check your status in the app.'},
                                  {'q': 'Is online voting secure?', 'a': 'Yes, E-Ballot uses encryption and multi-factor authentication to ensure security.'},
                                  {'q': 'Can I vote from any location?', 'a': 'Yes, as long as you have internet access and are a registered voter.'},
                                  {'q': 'How do I verify my identity?', 'a': 'You will need to provide your Voter ID and complete a face verification step.'},
                                  {'q': 'Can I change my vote after submitting?', 'a': 'No, once submitted, your vote is final and cannot be changed.'},
                                  {'q': 'How do I know my vote was counted?', 'a': 'You will receive a confirmation after voting, and you can check the status in the app.'},
                                  {'q': 'Is my vote anonymous?', 'a': 'Yes, all votes are anonymized and cannot be traced back to individuals.'},
                                  {'q': 'What if I forget my Voter ID?', 'a': 'You can recover your Voter ID through the official portal or contact support.'},
                                  {'q': 'Can I vote using my mobile device?', 'a': 'Yes, E-Ballot is accessible on smartphones, tablets, and computers.'},
                                  {'q': 'What should I do if I face technical issues?', 'a': 'Contact support through the app or email support@eballot.com.'},
                                  {'q': 'Are there any fees for online voting?', 'a': 'No, using E-Ballot is completely free for all eligible voters.'},
                                  {'q': 'How do I access live election results?', 'a': 'Tap the "Live Results" quick action on the Home Page.'},
                                  {'q': 'Can I participate in polls or surveys?', 'a': 'Yes, check the Home Page for Poll of the Day and other surveys.'},
                                  {'q': 'Is my personal data safe?', 'a': 'Yes, E-Ballot complies with all data protection regulations and never shares your data.'},
                                ],
                              );
                            },
                          },
                          {
                            'label': 'Live Results',
                            'icon': Icons.bar_chart,
                            'onPressed': () {
                              _showQuickActionDialog('Live Results', 'View live election results here. (Feature coming soon)');
                            },
                          },
                        ][i];
                        final Matrix4 buttonTransformMatrix = isHovered
                            ? (Matrix4.identity()..scale(1.04))
                            : Matrix4.identity();
                        return Padding(
                          padding: EdgeInsets.only(right: i < 2 ? 12 : 0),
                          child: MouseRegion(
                            onEnter: (_) => setState(() => _hoveredActionIndex = i),
                            onExit: (_) => setState(() => _hoveredActionIndex = null),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOut,
                              transform: buttonTransformMatrix,
                              child: ElevatedButton.icon(
                                onPressed: buttonData['onPressed'] as void Function(),
                                icon: Icon(buttonData['icon'] as IconData, color: colorScheme.onPrimary),
                                label: Text(
                                  buttonData['label'] as String,
                                  style: TextStyle(color: colorScheme.onPrimary),
                                ),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  backgroundColor: isHovered
                                      ? colorScheme.primary.withOpacity(0.92)
                                      : colorScheme.primary,
                                  elevation: isHovered ? 6 : 2,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(width: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Election updates cards
                ..._filteredUpdates.asMap().entries.map((entry) {
                  final index = entry.key;
                  final update = entry.value;
                  final originalIndex = electionUpdates.indexOf(update);
                  final isHovered = _hoveredCardIndex == index;
                  final Matrix4 cardTransformMatrix = isHovered
                      ? (Matrix4.identity()..scale(1.02))
                      : Matrix4.identity();
                  return Column(
                    children: [
                      MouseRegion(
                        onEnter: (_) => setState(() => _hoveredCardIndex = index),
                        onExit: (_) => setState(() => _hoveredCardIndex = null),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          transform: cardTransformMatrix,
                          decoration: BoxDecoration(
                            boxShadow: isHovered
                                ? [
                                    BoxShadow(
                                      color: colorScheme.shadow.withOpacity(0.08),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ]
                                : [],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            splashColor: colorScheme.primary.withOpacity(0.08),
                            highlightColor: colorScheme.primary.withOpacity(0.04),
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                ),
                                builder: (context) {
                                  return Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          update['title'] ?? '',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 22,
                                            color: colorScheme.primary,
                                          ),
                                        ),
                                        if (update['date'] != null)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6.0, bottom: 12.0),
                                            child: Text(
                                              update['date']!,
                                              style: TextStyle(
                                                fontSize: 15,
                                                color: colorScheme.onSurface.withOpacity(0.7),
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ),
                                        Text(
                                          update['description'] ?? '',
                                          style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                            child: Card(
                              color: colorScheme.surface,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: ListTile(
                                  title: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        update['title'] ?? '',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                      if (update['date'] != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
                                          child: Text(
                                            update['date']!,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: colorScheme.onSurface.withOpacity(0.7),
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(update['description'] ?? '', style: TextStyle(color: colorScheme.onSurface)),
                                  leading: _getCardIcon(update, colorScheme: colorScheme),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                    ],
                  );
                }),
                // District-specific updates section
                if (ProfileData.userLocation.isNotEmpty && districtUpdates[ProfileData.userLocation] != null) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Updates for ${ProfileData.userLocation}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...districtUpdates[ProfileData.userLocation]!.map((update) => Column(
                    children: [
                      Card(
                        color: colorScheme.surface,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          title: Text(
                            update['title'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: colorScheme.primary,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (update['date'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0, bottom: 2.0),
                                  child: Text(
                                    update['date']!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurface.withOpacity(0.7),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              Text(update['description'] ?? '', style: TextStyle(color: colorScheme.onSurface)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  )),
                ],
                // Poll of the Day card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Card(
                    color: colorScheme.surface,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _hasVoted
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Poll of the Day',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _pollQuestion,
                                  style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Thank you for voting!',
                                  style: TextStyle(
                                    color: colorScheme.secondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Poll of the Day',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _pollQuestion,
                                  style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
                                ),
                                const SizedBox(height: 12),
                                ..._pollOptions.map((option) => RadioListTile<String>(
                                      title: Text(option, style: TextStyle(color: colorScheme.onSurface)),
                                      value: option,
                                      groupValue: _selectedPollOption,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedPollOption = value;
                                        });
                                      },
                                      activeColor: colorScheme.primary,
                                    )),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _selectedPollOption == null
                                        ? null
                                        : () {
                                            setState(() {
                                              _hasVoted = true;
                                            });
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      foregroundColor: colorScheme.onPrimary,
                                    ),
                                    child: const Text('Vote'),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                // Footer
                Padding(
                  padding: const EdgeInsets.only(top: 32.0, bottom: 8.0),
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () async {
                            final Uri emailLaunchUri = Uri(
                              scheme: 'mailto',
                              path: 'support@eballot.com',
                              query: 'subject=E-Ballot App Support',
                            );
                            if (await canLaunchUrl(emailLaunchUri)) {
                              await launchUrl(emailLaunchUri);
                            }
                          },
                          child: Text(
                            'Contact Support',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getCardColor(Map<String, String> update, {ColorScheme? colorScheme}) {
    colorScheme ??= Theme.of(context).colorScheme;
    final title = update['title']?.toLowerCase() ?? '';
    final desc = update['description']?.toLowerCase() ?? '';
    if (title.contains('result') || desc.contains('result') || title.contains('success')) {
      return colorScheme.secondaryContainer;
    } else if (title.contains('reminder') || desc.contains('reminder') || title.contains('education')) {
      return colorScheme.tertiaryContainer;
    } else if (title.contains('alert') || desc.contains('alert') || title.contains('guideline')) {
      return colorScheme.errorContainer;
    } else {
      return colorScheme.surface;
    }
  }

  Icon _getCardIcon(Map<String, String> update, {ColorScheme? colorScheme}) {
    colorScheme ??= Theme.of(context).colorScheme;
    final title = update['title']?.toLowerCase() ?? '';
    final desc = update['description']?.toLowerCase() ?? '';
    if (title.contains('vote') || desc.contains('vote')) {
      return const Icon(Icons.how_to_vote, color: Color(0xFF1976D2), size: 32);
    } else if (title.contains('schedule') || desc.contains('schedule')) {
      return const Icon(Icons.schedule, color: Color(0xFF6D4C41), size: 32);
    } else if (title.contains('guideline') || title.contains('alert') || desc.contains('guideline') || desc.contains('alert')) {
      return const Icon(Icons.announcement, color: Color(0xFFD32F2F), size: 32);
    } else if (title.contains('education') || desc.contains('education')) {
      return const Icon(Icons.school, color: Color(0xFF388E3C), size: 32);
    } else if (title.contains('result') || desc.contains('result')) {
      return const Icon(Icons.emoji_events, color: Color(0xFFFBC02D), size: 32);
    } else {
      return const Icon(Icons.campaign, color: Color(0xFF616161), size: 32);
    }
  }
}

// Search Page
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Candidates'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('candidates').snapshots(),
        builder: (context, snapshot) {
          print('Snapshot state: ${snapshot.connectionState}');
          print('Documents: ${snapshot.data?.docs}');

          if (snapshot.hasError) {
            return Center(child: Text('Error: 24{snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No candidates found.'));
          }

          final candidates = snapshot.data!.docs;

          return ListView.builder(
            itemCount: candidates.length,
            itemBuilder: (context, index) {
              final data = candidates[index].data() as Map<String, dynamic>;
              return ListTile(
                leading: const Icon(Icons.person),
                title: Text(data['name'] ?? 'No name'),
                subtitle: Text(data['party'] ?? 'No party'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              );
            },
          );
        },
      ),
    );
  }
}

// Vote Page
class VotePage extends StatefulWidget {
  final TextEditingController voterIdController;
  final VoidCallback onVerify;
  final String? voteMessage;
  final Color? voteMessageColor;

  const VotePage({
    super.key,
    required this.voterIdController,
    required this.onVerify,
    this.voteMessage,
    this.voteMessageColor,
  });

  @override
  State<VotePage> createState() => _VotePageState();
}

class _VotePageState extends State<VotePage> {
  XFile? _capturedFace;
  String? _faceResult;
  bool get _isVerified => widget.voteMessage == 'Verified!';

  // Voting state
  String? _selectedCandidate;
  bool _voteSubmitted = false;
  final List<String> _candidates = [
    'Candidate A',
    'Candidate B',
    'Candidate C',
  ];

  Future<void> _captureAndVerifyFace() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _capturedFace = image;
          // Placeholder: In a real app, compare with profile image
          _faceResult = 'Face verified (placeholder)!';
        });
      }
    } catch (e) {
      setState(() {
        _faceResult = 'Failed to capture: $e';
      });
    }
  }

  void _submitVote() {
    setState(() {
      _voteSubmitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: widget.voterIdController,
              decoration: const InputDecoration(
                labelText: 'Enter Voter ID',
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: widget.onVerify,
              child: const Text('Verify'),
            ),
            if (widget.voteMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  widget.voteMessage!,
                  style: TextStyle(
                    color: widget.voteMessageColor ?? Colors.green,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (_isVerified)
              Column(
                children: [
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _captureAndVerifyFace,
                    child: const Text('Capture & Verify Face'),
                  ),
                  if (_capturedFace != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: kIsWeb
                          ? Image.network(_capturedFace!.path, width: 200, height: 200)
                          : Image.file(File(_capturedFace!.path), width: 200, height: 200),
                    ),
                  if (_faceResult != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        _faceResult!,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  // Voting UI after face verification
                  if (_faceResult == 'Face verified (placeholder)!')
                    _voteSubmitted
                        ? Padding(
                            padding: const EdgeInsets.only(top: 24.0),
                            child: Text(
                              'Your vote has been recorded anonymously.',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              const SizedBox(height: 24),
                              const Text('Select a candidate:'),
                              ..._candidates.map((candidate) => RadioListTile<String>(
                                    title: Text(candidate),
                                    value: candidate,
                                    groupValue: _selectedCandidate,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedCandidate = value;
                                      });
                                    },
                                  )),
                              ElevatedButton(
                                onPressed: _selectedCandidate == null ? null : _submitVote,
                                child: const Text('Submit Vote'),
                              ),
                            ],
                          ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// Social Page
class SocialPage extends StatefulWidget {
  const SocialPage({super.key});

  @override
  State<SocialPage> createState() => _SocialPageState();
}

class _SocialPageState extends State<SocialPage> {
  final List<String> _communities = const [
    'Party A – Progress First',
    'Party B – Green Future',
    'Independent Group – Unity Alliance',
  ];
  final Set<int> _joinedIndexes = {};

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _communities.length,
      itemBuilder: (context, index) {
        final joined = _joinedIndexes.contains(index);
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            title: Text(_communities[index]),
            trailing: ElevatedButton(
              onPressed: joined
                  ? null
                  : () {
                      setState(() {
                        _joinedIndexes.add(index);
                      });
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: joined
                    ? Colors.grey
                    : Theme.of(context).colorScheme.primary,
              ),
              child: Text(joined ? 'Joined' : 'Join'),
            ),
          ),
        );
      },
    );
  }
}

// Profile Page
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  Map<String, dynamic>? _savedProfile;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImage = null;
        });
      } else {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _selectedImageBytes = null;
        });
      }
    }
  }

  void _saveProfile() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _savedProfile = {
          'name': _nameController.text,
          'age': _ageController.text,
          'location': _locationController.text,
          'image': kIsWeb ? _selectedImageBytes : _selectedImage,
          'isWeb': kIsWeb,
        };
        ProfileData.userName = _nameController.text;
        ProfileData.userLocation = _locationController.text;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved locally!')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => value == null || value.isEmpty ? 'Enter your name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ageController,
                  decoration: const InputDecoration(labelText: 'Age'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Enter your age';
                    final age = int.tryParse(value);
                    if (age == null || age <= 0) return 'Enter a valid age';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(labelText: 'Location'),
                  validator: (value) => value == null || value.isEmpty ? 'Enter your location' : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _pickImage,
                      child: const Text('Pick Image'),
                    ),
                    const SizedBox(width: 16),
                    if (kIsWeb && _selectedImageBytes != null)
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
                        ),
                      )
                    else if (!kIsWeb && _selectedImage != null)
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_selectedImage!, fit: BoxFit.cover),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _saveProfile,
                  child: const Text('Save Profile'),
                ),
              ],
            ),
          ),
          if (_savedProfile != null) ...[
            const SizedBox(height: 32),
            const Text('Saved Profile:', style: TextStyle(fontWeight: FontWeight.bold)),
            ListTile(
              leading: _savedProfile!['isWeb'] == true && _savedProfile!['image'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(_savedProfile!['image'], width: 48, height: 48, fit: BoxFit.cover),
                    )
                  : _savedProfile!['image'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(_savedProfile!['image'], width: 48, height: 48, fit: BoxFit.cover),
                        )
                      : const Icon(Icons.account_circle, size: 48),
              title: Text(_savedProfile!['name'] ?? ''),
              subtitle: Text('Age: \\${_savedProfile!['age']}\nLocation: \\${_savedProfile!['location']}'),
            ),
          ],
        ],
      ),
    );
  }
}

// Add this widget at the end of the file or after SearchPage
class CandidateDetailPage extends StatelessWidget {
  final Map<String, dynamic> candidate;
  const CandidateDetailPage({super.key, required this.candidate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(candidate['name'] ?? 'Candidate Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Party: ${candidate['party'] ?? '-'}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            Text('State: ${candidate['state'] ?? '-'}', style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 12),
            Text('Constituency: ${candidate['constituency'] ?? '-'}', style: const TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}

// --- Candidate Firestore Search Page ---
class CandidateFirestoreSearchPage extends StatefulWidget {
  const CandidateFirestoreSearchPage({super.key});

  @override
  State<CandidateFirestoreSearchPage> createState() => _CandidateFirestoreSearchPageState();
}

class _CandidateFirestoreSearchPageState extends State<CandidateFirestoreSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Candidates'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('candidates').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final docs = snapshot.data?.docs ?? [];
                final filtered = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>?;
                  if (data == null) return false;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  return _searchQuery.isEmpty || name.contains(_searchQuery);
                }).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No candidates found.'));
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final data = filtered[index].data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(data['name'] ?? 'No name'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CandidateDetailPage(candidate: data),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class FirestoreCandidateSearch extends StatefulWidget {
  const FirestoreCandidateSearch({super.key});

  @override
  State<FirestoreCandidateSearch> createState() => _FirestoreCandidateSearchState();
}

class _FirestoreCandidateSearchState extends State<FirestoreCandidateSearch> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Candidate Search')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search candidates by name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('candidates').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: 24{snapshot.error}'));
                  }
                  final docs = snapshot.data?.docs ?? [];
                  final filtered = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>?;
                    if (data == null) return false;
                    final name = (data['name'] ?? '').toString().toLowerCase();
                    return _searchQuery.isEmpty || name.contains(_searchQuery);
                  }).toList();
                  if (filtered.isEmpty) {
                    return const Center(child: Text('No candidates found.'));
                  }
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final data = filtered[index].data() as Map<String, dynamic>?;
                      if (data == null) return const SizedBox.shrink();
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 2.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['name'] ?? '-',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text('Party: \\${data['party'] ?? '-'}'),
                              Text('State: \\${data['state'] ?? '-'}'),
                              Text('Constituency: \\${data['constituency'] ?? '-'}'),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
