// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AgriNexus AI';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get logout => 'Logout';

  @override
  String get email => 'Email';

  @override
  String get phone => 'Phone Number';

  @override
  String get password => 'Password';

  @override
  String get fullName => 'Full Name';

  @override
  String get dontHaveAccount => 'Don\'t have an account? Register';

  @override
  String get alreadyHaveAccount => 'Already have an account? Login';

  @override
  String get loginFailed => 'Incorrect email or password';

  @override
  String get registrationFailed =>
      'Registration failed. Please check your details.';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get myProfile => 'My Profile';

  @override
  String get myFarms => 'My Farms';

  @override
  String get myCrops => 'My Crops';

  @override
  String get aiPlantDoctor => 'AI Plant Doctor';

  @override
  String get pestIdentification => 'Pest Identification';

  @override
  String get cropRecommendation => 'Crop Recommendation';

  @override
  String get weather => 'Weather';

  @override
  String get farmerFeedback => 'Report an Issue';

  @override
  String get marketplace => 'Marketplace';

  @override
  String get registerAs => 'Register as';

  @override
  String get roleFarmer => 'Farmer';

  @override
  String get roleBuyer => 'Buyer';

  @override
  String get roleSupplier => 'Supplier';

  @override
  String get district => 'District';

  @override
  String get location => 'Location';

  @override
  String get farmerInfo => 'About You';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get changePhoto => 'Change Photo';

  @override
  String get addFarm => 'Add Farm';

  @override
  String get editFarm => 'Edit Farm';

  @override
  String get farmName => 'Farm Name';

  @override
  String get farmSize => 'Farm Size (acres)';

  @override
  String get soilInfo => 'Soil Information';

  @override
  String get waterAvailability => 'Water Availability';

  @override
  String get deleteFarm => 'Delete Farm';

  @override
  String get confirmDeleteFarm =>
      'Are you sure you want to delete this farm? This cannot be undone.';

  @override
  String get noFarmsYet => 'You haven\'t added any farms yet.';

  @override
  String get addCrop => 'Add Crop';

  @override
  String get cropName => 'Crop Name';

  @override
  String get plantingDate => 'Planting Date';

  @override
  String get expectedHarvestDate => 'Expected Harvest Date';

  @override
  String get cropStatus => 'Status';

  @override
  String get cropHistory => 'Crop History';

  @override
  String get noCropsYet => 'No crops added yet.';

  @override
  String get selectFarmFirst => 'Please select a farm first';

  @override
  String get captureImage => 'Take Photo';

  @override
  String get chooseFromGallery => 'Choose from Gallery';

  @override
  String get analyzing => 'Analyzing image...';

  @override
  String get confidence => 'Confidence';

  @override
  String get symptoms => 'Symptoms';

  @override
  String get recommendedActions => 'Recommended Actions';

  @override
  String get aiDisclaimer =>
      'This AI result is not guaranteed to be accurate. Please consult an agricultural expert before taking major action.';

  @override
  String get mockResultNotice =>
      'Demo mode: this result is from a test model, not a trained AI model.';

  @override
  String get detectionHistory => 'Detection History';

  @override
  String get soilPh => 'Soil pH';

  @override
  String get nitrogen => 'Nitrogen';

  @override
  String get phosphorus => 'Phosphorus';

  @override
  String get potassium => 'Potassium';

  @override
  String get temperature => 'Temperature (°C)';

  @override
  String get humidity => 'Humidity (%)';

  @override
  String get rainfall => 'Rainfall (mm)';

  @override
  String get season => 'Season';

  @override
  String get getRecommendations => 'Get Recommendations';

  @override
  String get suitability => 'Suitability';

  @override
  String get reasons => 'Reasons';

  @override
  String get warnings => 'Warnings';

  @override
  String get recommendationDisclaimer =>
      'These recommendations are decision support based on general agronomic guidelines, not guaranteed agricultural advice.';

  @override
  String get currentWeather => 'Current Weather';

  @override
  String get agriAdvisories => 'Agricultural Advisories';

  @override
  String get enterLocation => 'Enter your location';

  @override
  String get feedbackType => 'Type of Issue';

  @override
  String get description => 'Description (optional)';

  @override
  String get submitFeedback => 'Submit Report';

  @override
  String get feedbackSubmitted => 'Report submitted successfully';

  @override
  String get myReports => 'My Reports';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading...';

  @override
  String get noDataYet => 'Nothing here yet';

  @override
  String get somethingWentWrong => 'Something went wrong. Please try again.';

  @override
  String get networkError =>
      'Could not connect. Check your internet connection.';

  @override
  String get requiredField => 'This field is required';

  @override
  String get confirm => 'Confirm';

  @override
  String get waterAvailabilityAbundant => 'Abundant';

  @override
  String get waterAvailabilityModerate => 'Moderate';

  @override
  String get waterAvailabilityLimited => 'Limited';

  @override
  String get waterAvailabilityNone => 'None';

  @override
  String get cropStatusPlanned => 'Planned';

  @override
  String get cropStatusPlanted => 'Planted';

  @override
  String get cropStatusGrowing => 'Growing';

  @override
  String get cropStatusReadyForHarvest => 'Ready for Harvest';

  @override
  String get cropStatusHarvested => 'Harvested';

  @override
  String get cropStatusFailed => 'Failed';

  @override
  String get feedbackWaterlogging => 'Waterlogging';

  @override
  String get feedbackDrought => 'Drought';

  @override
  String get feedbackSalinity => 'Salinity';

  @override
  String get feedbackPestOutbreak => 'Pest Outbreak';

  @override
  String get feedbackDiseaseOutbreak => 'Disease Outbreak';

  @override
  String get feedbackUnexpectedWeather => 'Unexpected Weather';

  @override
  String get feedbackCropGrowthProblem => 'Crop Growth Problem';

  @override
  String get feedbackOther => 'Other';

  @override
  String get community => 'Community';

  @override
  String get chats => 'Chats';

  @override
  String get adminReports => 'Review Reports';

  @override
  String get noConversations =>
      'No conversations yet. Message someone from a community post.';

  @override
  String get typeMessage => 'Type a message…';

  @override
  String get send => 'Send';

  @override
  String get noMessages => 'No messages yet. Say hello!';

  @override
  String get messageAuthor => 'Message';

  @override
  String aboutListing(String title) {
    return 'About: $title';
  }

  @override
  String get you => 'You';

  @override
  String get newPost => 'New Post';

  @override
  String get editPost => 'Edit Post';

  @override
  String get postTitle => 'Title';

  @override
  String get postBody => 'What would you like to share?';

  @override
  String get postCategory => 'Category';

  @override
  String get addImage => 'Add Image';

  @override
  String get removeImage => 'Remove Image';

  @override
  String get publish => 'Publish';

  @override
  String get noPosts => 'No posts yet. Be the first to share!';

  @override
  String get searchPosts => 'Search posts';

  @override
  String get filterAll => 'All';

  @override
  String get categoryGeneral => 'General';

  @override
  String get categoryCrops => 'Crops';

  @override
  String get categoryPestsDiseases => 'Pests & Diseases';

  @override
  String get categoryWeather => 'Weather';

  @override
  String get categoryMarket => 'Market';

  @override
  String get categoryEquipment => 'Equipment';

  @override
  String get categoryOther => 'Other';

  @override
  String get comments => 'Comments';

  @override
  String get noComments => 'No comments yet';

  @override
  String get writeComment => 'Write a comment…';

  @override
  String get deletePost => 'Delete Post';

  @override
  String get confirmDeletePost => 'Delete this post? This cannot be undone.';

  @override
  String get deleteComment => 'Delete Comment';

  @override
  String get confirmDeleteComment => 'Delete this comment?';

  @override
  String get editComment => 'Edit Comment';

  @override
  String get report => 'Report';

  @override
  String get reportContent => 'Report Content';

  @override
  String get reportUser => 'Report User';

  @override
  String get reportReason => 'Reason';

  @override
  String get reportDetails => 'Details (optional)';

  @override
  String get reportSubmitted => 'Thanks. An admin will review your report.';

  @override
  String get alreadyReported => 'You have already reported this.';

  @override
  String get reasonSpam => 'Spam';

  @override
  String get reasonHarassment => 'Harassment';

  @override
  String get reasonInappropriate => 'Inappropriate';

  @override
  String get reasonMisinformation => 'Misinformation';

  @override
  String get reasonScam => 'Scam';

  @override
  String get reasonOther => 'Other';

  @override
  String get reportStatusOpen => 'Open';

  @override
  String get reportStatusReviewed => 'Reviewed';

  @override
  String get reportStatusResolved => 'Resolved';

  @override
  String get reportStatusDismissed => 'Dismissed';

  @override
  String get targetPost => 'Post';

  @override
  String get targetComment => 'Comment';

  @override
  String get targetUser => 'User';

  @override
  String get targetListing => 'Listing';

  @override
  String get markReviewed => 'Mark Reviewed';

  @override
  String get resolve => 'Resolve';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get adminNote => 'Note (optional)';

  @override
  String get noReports => 'No reports';

  @override
  String reportedBy(String name) {
    return 'Reported by $name';
  }

  @override
  String get targetDeleted => 'This item no longer exists';

  @override
  String get postNotFound => 'This post no longer exists.';

  @override
  String get notAllowed => 'You don\'t have permission to do that.';

  @override
  String get reportUpdated => 'Report updated';

  @override
  String get adminOnly => 'Only admins can view this page.';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleCommunityMember => 'Community Member';
}
