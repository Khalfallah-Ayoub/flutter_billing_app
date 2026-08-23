import '../../../../core/data/hive_database.dart';
import '../models/customer_model.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/invoice.dart';

class CustomerService {
  static List<Customer> getCustomers() {
    final box = HiveDatabase.customerBox;
    return box.values.map((model) => model.toEntity()).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Customer? getCustomerById(String id) {
    final box = HiveDatabase.customerBox;
    final model = box.get(id);
    return model?.toEntity();
  }

  static Future<void> saveCustomer(Customer customer) async {
    final box = HiveDatabase.customerBox;
    final model = CustomerModel.fromEntity(customer);
    await box.put(customer.id, model);
  }

  static Future<void> deleteCustomer(String id) async {
    final box = HiveDatabase.customerBox;
    await box.delete(id);
  }

  static double getCustomerTotalDebt(String customerId, List<Invoice> allInvoices) {
    return allInvoices
        .where((inv) => inv.customerId == customerId || (inv.customerName == getCustomerById(customerId)?.name))
        .fold(0.0, (sum, inv) => sum + inv.remainingAmount);
  }

  static double getCustomerTotalPurchases(String customerId, List<Invoice> allInvoices) {
    return allInvoices
        .where((inv) => inv.customerId == customerId || (inv.customerName == getCustomerById(customerId)?.name))
        .fold(0.0, (sum, inv) => sum + inv.totalAmount);
  }
}
