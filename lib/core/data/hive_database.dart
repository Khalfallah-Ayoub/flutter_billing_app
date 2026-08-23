import 'package:hive_flutter/hive_flutter.dart';
import '../../features/product/data/models/product_model.dart';
import '../../features/shop/data/models/shop_model.dart';
import '../../features/invoice/data/models/customer_model.dart';
import '../../features/invoice/data/models/invoice_item_model.dart';
import '../../features/invoice/data/models/invoice_model.dart';
import '../../features/invoice/data/models/payment_record_model.dart';

class HiveDatabase {
  static const String productBoxName = 'products';
  static const String shopBoxName = 'shop';
  static const String settingsBoxName = 'settings';
  static const String feedbackBoxName = 'feedback';
  static const String customerBoxName = 'customers';
  static const String invoiceBoxName = 'invoices';

  static Future<void> init() async {
    await Hive.initFlutter();

    // Register Adapters
    Hive.registerAdapter(ProductModelAdapter());
    Hive.registerAdapter(ShopModelAdapter());
    Hive.registerAdapter(CustomerModelAdapter());
    Hive.registerAdapter(InvoiceItemModelAdapter());
    Hive.registerAdapter(InvoiceModelAdapter());
    Hive.registerAdapter(PaymentRecordModelAdapter());

    // Open Boxes
    await Hive.openBox<ProductModel>(productBoxName);
    await Hive.openBox<ShopModel>(shopBoxName);
    await Hive.openBox(settingsBoxName); // Generic box for simple key-value
    await Hive.openBox(feedbackBoxName); // Generic box for recognition feedback records
    await Hive.openBox<CustomerModel>(customerBoxName);
    await Hive.openBox<InvoiceModel>(invoiceBoxName);
  }

  static Box<ProductModel> get productBox =>
      Hive.box<ProductModel>(productBoxName);
  static Box<ShopModel> get shopBox => Hive.box<ShopModel>(shopBoxName);
  static Box get settingsBox => Hive.box(settingsBoxName);
  static Box get feedbackBox => Hive.box(feedbackBoxName);
  static Box<CustomerModel> get customerBox =>
      Hive.box<CustomerModel>(customerBoxName);
  static Box<InvoiceModel> get invoiceBox =>
      Hive.box<InvoiceModel>(invoiceBoxName);
}
