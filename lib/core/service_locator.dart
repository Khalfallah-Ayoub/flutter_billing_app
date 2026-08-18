import 'package:get_it/get_it.dart';
import '../../features/product/data/repositories/product_repository_impl.dart';
import '../../features/product/domain/repositories/product_repository.dart';
import '../../features/product/domain/usecases/product_usecases.dart';
import '../../features/product/presentation/bloc/product_bloc.dart';
import '../../features/shop/data/repositories/shop_repository_impl.dart';
import '../../features/shop/domain/repositories/shop_repository.dart';
import '../../features/shop/domain/usecases/shop_usecases.dart';
import '../../features/shop/presentation/bloc/shop_bloc.dart';
import '../../features/settings/data/repositories/printer_repository_impl.dart';
import '../../features/settings/domain/repositories/printer_repository.dart';
import '../../features/settings/presentation/bloc/printer_bloc.dart';
import 'package:billing_app/core/utils/image_storage_service.dart';
import '../../features/smart_recognition/data/services/ocr_service.dart';
import '../../features/smart_recognition/data/services/embedding_service.dart';
import '../../features/smart_recognition/data/services/vector_search_service.dart';
import '../../features/smart_recognition/data/services/ranking_service.dart';
import '../../features/smart_recognition/presentation/bloc/recognition_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Features - Product
  // Bloc
  sl.registerFactory(
    () => ProductBloc(
      getProductsUseCase: sl(),
      addProductUseCase: sl(),
      updateProductUseCase: sl(),
      deleteProductUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => ShopBloc(
      getShopUseCase: sl(),
      updateShopUseCase: sl(),
    ),
  );

  sl.registerFactory(
    () => PrinterBloc(
      repository: sl(),
    ),
  );

  // Features - Smart Recognition Bloc
  sl.registerFactory(
    () => RecognitionBloc(
      ocrService: sl(),
      embeddingService: sl(),
      rankingService: sl(),
      imageStorageService: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => GetProductsUseCase(sl()));
  sl.registerLazySingleton(() => AddProductUseCase(sl()));
  sl.registerLazySingleton(() => UpdateProductUseCase(sl()));
  sl.registerLazySingleton(() => DeleteProductUseCase(sl()));
  sl.registerLazySingleton(() => GetProductByBarcodeUseCase(sl()));

  // Repository
  sl.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(),
  );

  // Features - Shop
  // Use cases
  sl.registerLazySingleton(() => GetShopUseCase(sl()));
  sl.registerLazySingleton(() => UpdateShopUseCase(sl()));

  // Repository
  sl.registerLazySingleton<ShopRepository>(
    () => ShopRepositoryImpl(),
  );

  // Features - Settings / Printer
  sl.registerLazySingleton<PrinterRepository>(
    () => PrinterRepositoryImpl(),
  );

  // Core Services - Smart Recognition
  sl.registerLazySingleton<ImageStorageService>(
    () => ImageStorageService(),
  );
  sl.registerLazySingleton<OcrService>(
    () => OcrService(),
  );
  sl.registerLazySingleton<EmbeddingService>(
    () => EmbeddingService(),
  );
  sl.registerLazySingleton<VectorSearchService>(
    () => VectorSearchService(),
  );
  sl.registerLazySingleton<RankingService>(
    () => RankingService(
      ocrService: sl(),
      vectorSearchService: sl(),
    ),
  );
}
