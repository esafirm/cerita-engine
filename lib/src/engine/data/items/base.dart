import 'package:fsse/src/engine/data/items/profile_info.dart';

abstract class ItemType {
  const ItemType();

  String? getText();

  String getType();

  ProfileInfo? getProfileInfo();

  ItemType cloneWithData(Map<String, String> data);
}

