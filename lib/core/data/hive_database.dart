import 'package:hive_flutter/hive_flutter.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/shop/data/models/shop_model.dart';
import '../../features/invoice/data/models/customer_model.dart';
import '../../features/invoice/data/models/invoice_item_model.dart';
import '../../features/invoice/data/models/invoice_model.dart';
import '../../features/invoice/data/models/payment_record_model.dart';
import '../../features/expense/data/models/expense_model.dart';
import '../../features/craftsman/data/models/craftsman_model.dart';
import '../../features/returns/data/models/return_invoice_model.dart';

class HiveDatabase {
  static const String productBoxName = 'products';
  static const String shopBoxName = 'shop';
  static const String settingsBoxName = 'settings';
  static const String feedbackBoxName = 'feedback';
  static const String customerBoxName = 'customers';
  static const String invoiceBoxName = 'invoices';
  static const String expenseBoxName = 'expenses';
  static const String craftsmanBoxName = 'craftsmen';
  static const String returnInvoiceBoxName = 'return_invoices';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register Adapters
    Hive.registerAdapter(ProductModelAdapter());
    Hive.registerAdapter(ShopModelAdapter());
    Hive.registerAdapter(CustomerModelAdapter());
    Hive.registerAdapter(InvoiceItemModelAdapter());
    Hive.registerAdapter(InvoiceModelAdapter());
    Hive.registerAdapter(PaymentRecordModelAdapter());
    Hive.registerAdapter(ExpenseModelAdapter());
    Hive.registerAdapter(CraftsmanModelAdapter());
    Hive.registerAdapter(ReturnItemModelAdapter());
    Hive.registerAdapter(ReturnInvoiceModelAdapter());

    // Open Boxes
    await Hive.openBox<ProductModel>(productBoxName);
    await Hive.openBox<ShopModel>(shopBoxName);
    await Hive.openBox(settingsBoxName);
    await Hive.openBox(feedbackBoxName);
    await Hive.openBox<CustomerModel>(customerBoxName);
    await Hive.openBox<InvoiceModel>(invoiceBoxName);
    await Hive.openBox<ExpenseModel>(expenseBoxName);
    await Hive.openBox<CraftsmanModel>(craftsmanBoxName);
    await Hive.openBox<ReturnInvoiceModel>(returnInvoiceBoxName);
  }

  static Box<ProductModel> get productBox => Hive.box<ProductModel>(productBoxName);
  static Box<ShopModel> get shopBox => Hive.box<ShopModel>(shopBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);
  static Box get feedbackBox => Hive.box(feedbackBoxName);
  static Box<CustomerModel> get customerBox => Hive.box<CustomerModel>(customerBoxName);
  static Box<InvoiceModel> get invoiceBox => Hive.box<InvoiceModel>(invoiceBoxName);
  static Box<ExpenseModel> get expenseBox => Hive.box<ExpenseModel>(expenseBoxName);
  static Box<CraftsmanModel> get craftsmanBox => Hive.box<CraftsmanModel>(craftsmanBoxName);
  static Box<ReturnInvoiceModel> get returnInvoiceBox => Hive.box<ReturnInvoiceModel>(returnInvoiceBoxName);
}
