import 'base.dart';

/// Silent router: jumps to the first branch whose condition holds, else [fallbackTarget].
class BranchItemType extends ItemType {
  static const type = "BRANCH";

  final List<Branch> branches;
  final String? fallbackTarget;

  BranchItemType.fromJson(super.json)
      : branches = (json["branches"] as List<dynamic>? ?? const [])
            .map((e) => Branch.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        fallbackTarget = json["fallback_target"] as String?;

  @override
  String getType() => type;

  @override
  String? getText() => null;
}

class Branch {
  final String condition;
  final String target;

  const Branch(this.condition, this.target);

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(json["condition"] as String, json["target"] as String);
}
