// أدوار المستخدمين
enum UserRole { 
  collector,
  manager,
  accountant
}

// حالة السند المالي
enum TransactionStatus { 
  pending,  
  approvedByCollector,       
  approvedByManager, 
  approvedByAccountant, 
  reviewRequestedByAccountant, 
  reviewRequestedByManager,
  editRequestedByCollector,
  rejectedByManager,
}