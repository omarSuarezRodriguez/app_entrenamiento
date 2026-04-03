import 'package:get/get.dart';

class AppShellController extends GetxController {
  final RxInt selectedIndex = 0.obs;

  void setIndex(int index) {
    selectedIndex.value = index;
  }
}
