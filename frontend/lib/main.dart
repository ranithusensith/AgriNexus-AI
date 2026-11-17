import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'shared/l10n/app_localizations.dart';
import 'shared/models/detection_result.dart';
import 'shared/models/farm.dart';
import 'shared/routes.dart';
import 'shared/state/auth_provider.dart';
import 'shared/state/locale_provider.dart';
import 'shared/widgets/common_widgets.dart';

import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/dashboard/farmer_dashboard_screen.dart';
import 'features/profile/farmer_profile_screen.dart';
import 'features/farms/my_farms_screen.dart';
import 'features/farms/add_edit_farm_screen.dart';
import 'features/farms/farm_details_screen.dart';
import 'features/crops/my_crops_screen.dart';
import 'features/crops/add_crop_screen.dart';
import 'features/crops/crop_details_screen.dart';
import 'features/ai_disease/ai_plant_doctor_screen.dart';
import 'features/ai_disease/disease_result_screen.dart';
import 'features/pest/pest_identification_screen.dart';
import 'features/recommendation/crop_recommendation_screen.dart';
import 'features/weather/weather_screen.dart';
import 'features/feedback/farmer_feedback_screen.dart';
import 'features/marketplace/providers/marketplace_provider.dart';
import 'features/marketplace/screens/marketplace_home_screen.dart';
import 'features/marketplace/services/marketplace_api_service.dart';
import 'features/orders/providers/order_provider.dart';
import 'features/products/providers/listing_provider.dart';
import 'features/chat/models/conversation.dart';
import 'features/chat/providers/chat_provider.dart';
import 'features/chat/screens/chat_screen.dart';
import 'features/chat/screens/conversations_screen.dart';
import 'features/chat/services/chat_api_service.dart';
import 'features/community/models/post.dart';
import 'features/community/providers/community_feed_provider.dart';
import 'features/community/screens/community_feed_screen.dart';
import 'features/community/screens/create_post_screen.dart';
import 'features/community/screens/post_details_screen.dart';
import 'features/community/services/community_api_service.dart';
import 'features/issue_reports/screens/admin_reports_screen.dart';
import 'features/issue_reports/services/issue_report_api_service.dart';
import 'shared/api/api_client.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AgriNexusApp());
}

class AgriNexusApp extends StatelessWidget {
  const AgriNexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..bootstrap()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()..loadSavedLocale()),
        // Module 2 (Marketplace) shares one API service instance.
        Provider(create: (_) => MarketplaceApiService(ApiClient.instance)),
        ChangeNotifierProvider(create: (c) => MarketplaceProvider(c.read<MarketplaceApiService>())),
        ChangeNotifierProvider(create: (c) => ListingProvider(c.read<MarketplaceApiService>())),
        ChangeNotifierProvider(create: (c) => OrderProvider(c.read<MarketplaceApiService>())),
        // Module 3 (Communication + Community)
        Provider(create: (_) => CommunityApiService(ApiClient.instance)),
        Provider(create: (_) => ChatApiService(ApiClient.instance)),
        Provider(create: (_) => IssueReportApiService(ApiClient.instance)),
        ChangeNotifierProvider(create: (c) => CommunityFeedProvider(c.read<CommunityApiService>())),
        ChangeNotifierProvider(create: (c) => ChatProvider(c.read<ChatApiService>())),
      ],
      child: Consumer<LocaleProvider>(
        builder: (context, localeProvider, _) {
          return MaterialApp(
            title: 'AgriNexus AI',
            debugShowCheckedModeBanner: false,
            locale: localeProvider.locale,
            supportedLocales: kSupportedLocales,
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              colorSchemeSeed: Colors.green,
              useMaterial3: true,
              inputDecorationTheme: const InputDecorationTheme(
                filled: false,
              ),
            ),
            home: const _AuthGate(),
            onGenerateRoute: _onGenerateRoute,
          );
        },
      ),
    );
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case AppRoutes.register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case AppRoutes.dashboard:
        return MaterialPageRoute(builder: (_) => const FarmerDashboardScreen());
      case AppRoutes.profile:
        return MaterialPageRoute(builder: (_) => const FarmerProfileScreen());
      case AppRoutes.myFarms:
        return MaterialPageRoute(builder: (_) => const MyFarmsScreen());
      case AppRoutes.addEditFarm:
        final farm = settings.arguments as Farm?;
        return MaterialPageRoute(builder: (_) => AddEditFarmScreen(existingFarm: farm));
      case AppRoutes.farmDetails:
        final farmId = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => FarmDetailsScreen(farmId: farmId));
      case AppRoutes.myCrops:
        return MaterialPageRoute(builder: (_) => const MyCropsScreen());
      case AppRoutes.addCrop:
        final farmId = settings.arguments as String?;
        return MaterialPageRoute(builder: (_) => AddCropScreen(preselectedFarmId: farmId));
      case AppRoutes.cropDetails:
        final cropId = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => CropDetailsScreen(cropId: cropId));
      case AppRoutes.aiPlantDoctor:
        return MaterialPageRoute(builder: (_) => const AiPlantDoctorScreen());
      case AppRoutes.diseaseResult:
        final result = settings.arguments as DiseaseResult;
        return MaterialPageRoute(builder: (_) => DiseaseResultScreen(result: result));
      case AppRoutes.pestIdentification:
        return MaterialPageRoute(builder: (_) => const PestIdentificationScreen());
      case AppRoutes.cropRecommendation:
        return MaterialPageRoute(builder: (_) => const CropRecommendationScreen());
      case AppRoutes.weather:
        return MaterialPageRoute(builder: (_) => const WeatherScreen());
      case AppRoutes.farmerFeedback:
        return MaterialPageRoute(builder: (_) => const FarmerFeedbackScreen());
      case AppRoutes.marketplace:
        return MaterialPageRoute(builder: (_) => const MarketplaceHomeScreen());
      case AppRoutes.community:
        return MaterialPageRoute(builder: (_) => const CommunityFeedScreen());
      case AppRoutes.communityPost:
        final postId = settings.arguments as String;
        return MaterialPageRoute(builder: (_) => PostDetailsScreen(postId: postId));
      case AppRoutes.createPost:
        final post = settings.arguments as Post?;
        return MaterialPageRoute(builder: (_) => CreatePostScreen(existing: post));
      case AppRoutes.conversations:
        return MaterialPageRoute(builder: (_) => const ConversationsScreen());
      case AppRoutes.chat:
        final conversation = settings.arguments as Conversation;
        return MaterialPageRoute(builder: (_) => ChatScreen(conversation: conversation));
      case AppRoutes.adminReports:
        return MaterialPageRoute(builder: (_) => const AdminReportsScreen());
      default:
        return null;
    }
  }
}

/// Shows the dashboard if a valid session exists, otherwise the login
/// screen. This is the app's home widget; all other navigation goes through
/// named routes.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    switch (auth.status) {
      case AuthStatus.unknown:
        return const Scaffold(body: LoadingView());
      case AuthStatus.authenticated:
        return const FarmerDashboardScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
