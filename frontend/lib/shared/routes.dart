class AppRoutes {
  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/dashboard';
  static const profile = '/profile';
  static const myFarms = '/farms';
  static const addEditFarm = '/farms/edit';
  static const farmDetails = '/farms/details';
  static const myCrops = '/crops';
  static const addCrop = '/crops/add';
  static const cropDetails = '/crops/details';
  static const aiPlantDoctor = '/ai/disease';
  static const diseaseResult = '/ai/disease/result';
  static const pestIdentification = '/ai/pest';
  static const cropRecommendation = '/ai/recommendation';
  static const weather = '/weather';
  static const farmerFeedback = '/feedback';
  static const marketplace = '/marketplace';

  // Module 3 (Communication + Community)
  static const community = '/community';
  static const communityPost = '/community/post'; // arguments: String postId
  static const createPost = '/community/post/edit'; // arguments: Post? (null = new)
  static const conversations = '/chat';
  static const chat = '/chat/conversation'; // arguments: Conversation
  static const adminReports = '/admin/reports';
}
