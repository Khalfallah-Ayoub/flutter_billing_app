import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'config/routes/app_routes.dart';
import 'core/data/hive_database.dart';
import 'core/service_locator.dart' as di;
import 'core/theme/app_theme.dart';
import 'core/theme/theme_cubit.dart';
import 'features/billing/presentation/bloc/billing_bloc.dart';
import 'features/product/presentation/bloc/product_bloc.dart';
import 'features/shop/presentation/bloc/shop_bloc.dart';
import 'features/settings/presentation/bloc/printer_bloc.dart';
import 'features/settings/presentation/bloc/printer_event.dart';
import 'features/invoice/presentation/bloc/invoice_bloc.dart';
import 'features/invoice/presentation/bloc/customer_bloc.dart';
import 'features/expense/presentation/bloc/expense_bloc.dart';
import 'features/craftsman/presentation/bloc/craftsman_bloc.dart';
import 'features/returns/presentation/bloc/return_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Custom error UI instead of white screen if any widget fails
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'حدث خطأ في النظام',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  };

  try {
    await HiveDatabase.init();
    await di.init();
  } catch (e, stack) {
    debugPrint('Startup init error: $e\n$stack');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ProductBloc>(
            create: (context) => di.sl<ProductBloc>()..add(LoadProducts())),
        BlocProvider<ShopBloc>(
            create: (context) => di.sl<ShopBloc>()..add(LoadShopEvent())),
        BlocProvider<BillingBloc>(
            create: (context) =>
                BillingBloc(getProductByBarcodeUseCase: di.sl())),
        BlocProvider<PrinterBloc>(
            create: (context) => di.sl<PrinterBloc>()..add(InitPrinterEvent())),
        BlocProvider<ThemeCubit>(
            create: (context) => ThemeCubit()),
        BlocProvider<InvoiceBloc>(
            create: (context) => InvoiceBloc()..add(LoadInvoicesEvent())),
        BlocProvider<CustomerBloc>(
            create: (context) => CustomerBloc()..add(LoadCustomersEvent())),
        BlocProvider<ExpenseBloc>(
            create: (context) => ExpenseBloc()..add(LoadExpensesEvent())),
        BlocProvider<CraftsmanBloc>(
            create: (context) => CraftsmanBloc()..add(LoadCraftsmenEvent())),
        BlocProvider<ReturnBloc>(
            create: (context) => ReturnBloc()..add(LoadReturnsEvent())),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp.router(
            title: 'Billing App',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
