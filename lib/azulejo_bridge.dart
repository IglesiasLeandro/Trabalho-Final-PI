import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

final DynamicLibrary nativeLib = Platform.isAndroid
    ? DynamicLibrary.open("libazulejo_detector.so")
    : throw UnsupportedError("Este exemplo só roda no Android");

final Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>) getBestTitle =
    nativeLib
        .lookup<
          NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>)>
        >("get_best_title")
        .asFunction();

String detectarAzulejo(String imagePath, String azulejosDir) {
  final imagePtr = imagePath.toNativeUtf8();
  final dirPtr = azulejosDir.toNativeUtf8();
  final resultPtr = getBestTitle(imagePtr, dirPtr);
  final result = resultPtr.toDartString();
  calloc.free(imagePtr);
  calloc.free(dirPtr);
  return result;
}
