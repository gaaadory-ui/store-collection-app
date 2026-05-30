class BranchModel {
  final String id;
  final String name;
  final String branchManagerId; // تم التعديل إلى camelCase

  BranchModel({
    required this.id,
    required this.name,
    required this.branchManagerId,
  });

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      id: json['id'],
      name: json['name'],
      branchManagerId: json['branch_manager_id'], // مفتاح الفايربيس يبقى كما هو
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'branch_manager_id': branchManagerId,
    };
  }
}