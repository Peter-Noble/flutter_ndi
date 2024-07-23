import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'ndi_convert_bindings.dart';
import 'ndi_bindings.dart' as ndi_ffi;

ndi_ffi.NDI _ndi = ndi_ffi.NDI(ffi.DynamicLibrary.open(
    "C:\\Program Files\\NDI\\NDI 6 SDK\\Bin\\x64\\Processing.NDI.Lib.x64.dll"));
NDIConvert ndiConvert =
    NDIConvert(ffi.DynamicLibrary.open("bin/ndi_convert.dll"));

class NDI {
  /// A class wrapping around the NDI FFI bindings.
  NDI() {
    _ndi.NDIlib_v5_load();
    if (!_ndi.NDIlib_initialize()) {
      throw Exception("Could not initialize NDI");
    }
  }

  /// The internal pointer to the available NDI souces.
  ///
  /// Update this by calling [await updateSources()].
  ffi.Pointer<ndi_ffi.NDIlib_source_t>? _pSources;
  ndi_ffi.NDIlib_find_instance_t? _pFind;

  /// The List of [NDISource] containing available NDI sources.
  ///
  /// Update this by calling [await updateSources()].
  List<NDISource> sources = [];

  ffi.Pointer<ndi_ffi.NDIlib_source_t>? getSourceAt(int index) {
    if (_pSources == null) return null;
    return _pSources! + index;
  }

  /// Asynchronously update the [ndi.sources] list of NDI sources.
  ///
  /// Access updated sources with [ndi.sources] after waiting for this future to complete.
  Future<void> updateSoures() async {
    Completer completer = Completer();
    ReceivePort receivePort = ReceivePort();
    Isolate iso = await Isolate.spawn(
        _updateSourcePointer, _SMObject(receivePort.sendPort, _pFind?.address));
    receivePort.listen(
      (data) {
        if (data is Map<String, int>) {
          if (data["pSources"] == null || data["sourceCount"] == null) return;
          int sourceCount = data["sourceCount"]!;
          sources = [];
          if (sourceCount == 0) {
            completer.complete();
            receivePort.close();
            iso.kill(priority: Isolate.immediate);
            return;
          }
          _pSources = ffi.Pointer.fromAddress(data["pSources"]!)
              .cast<ndi_ffi.NDIlib_source_t>();

          for (int i = 0; i < sourceCount; i++) {
            sources.add(NDISource(_pSources! + i));
          }
          completer.complete();
          receivePort.close();
          iso.kill(priority: Isolate.immediate);
        }
      },
      onDone: () {},
    );
    return completer.future;
  }

  /// Invoked by the isolate in [updateSources()] to get a pointer to the new available ndi sources
  static void _updateSourcePointer(_SMObject object) {
    ffi.Pointer<ndi_ffi.NDIlib_find_create_t> pCreateSettings =
        calloc.call<ndi_ffi.NDIlib_find_create_t>(1);
    pCreateSettings.ref.show_local_sources = true;

    late ndi_ffi.NDIlib_find_instance_t pNDIfind;
    if (object.pFindA == null) {
      pNDIfind = _ndi.NDIlib_find_create2(pCreateSettings);
    } else {
      pNDIfind = ffi.Pointer.fromAddress(object.pFindA!);
    }
    if (!_ndi.NDIlib_find_wait_for_sources(pNDIfind, 10000)) {
      calloc.free(pCreateSettings);
      object.sendPort.send(<String, int>{
        "pSources": 0,
        "sourceCount": 0,
      });
      return;
    }
    sleep(const Duration(seconds: 1));

    final pSourceCount = calloc.call<ffi.Uint32>(1);
    final pSources =
        _ndi.NDIlib_find_get_current_sources(pNDIfind, pSourceCount);
    object.sendPort.send(<String, int>{
      "pSources": pSources.address,
      "sourceCount": pSourceCount.value,
    });

    calloc.free(pCreateSettings);
    calloc.free(pSourceCount);
  }

  ReceivePort? _fReceivePort;
  Isolate? _fIsolate;
  SendPort? _fIsoSendport;

  // SEND UPDATES FROM THE MAIN THREAD
  void updateMask(Rect mask, bool active) {
    if (_fIsoSendport != null) {
      _fIsoSendport!.send({
        // "mTop": mask.top,
        // "mLeft": mask.left,
        // "mWidth": mask.width,
        // "mHeight": mask.height,
        // "mActive": active,
      });
    }
  }

  /// A stream yielding the NDI Frames converted to an ui.Image.
  Future<void> getFrames(
    ffi.Pointer<ndi_ffi.NDIlib_source_t> source,
    Function(NDIOutputFrame frame) onFrame,
    // Rect mask,
    // bool maskActive,
  ) async {
    final completer = Completer();
    _fReceivePort = ReceivePort();

    _fReceivePort!.listen(
      (data) {
        // print("Received data");
        if (data is Map<String, int>) {
          if (data["pRGBA"] != null &&
              data["width"] != null &&
              data["height"] != null) {
            // print("Data is frame");
            ffi.Pointer<ffi.Uint8> pRGBA =
                ffi.Pointer.fromAddress(data["pRGBA"]!);

            // calloc.free(pRGBA);

            Uint8List pxs =
                pRGBA.asTypedList(data["width"]! * data["height"]! * 4);

            ui.decodeImageFromPixels(
                pxs, data["width"]!, data["height"]!, ui.PixelFormat.rgba8888,
                (iRGBA) {
              calloc.free(pRGBA);
              onFrame(NDIOutputFrame(iRGBA: iRGBA));
              _fIsoSendport!.send({"receivedFrame": true});
            });
          }
        }
        if (data is SendPort) {
          _fIsoSendport = data;
        }
      },
      onDone: () {
        completer.complete();
      },
    );

    _fIsolate = await Isolate.spawn(
        _getFrames, _FMObject(source.address, _fReceivePort!.sendPort));

    return completer.future;
  }

  void stopGetFrames() {
    if (_fIsolate == null || _fReceivePort == null) return;
    _fReceivePort!.close();
    _fIsolate!.kill(priority: Isolate.immediate);
    _fIsolate = null;
    _fReceivePort = null;
  }

  static void _getFrames(_FMObject object) async {
    ReceivePort rP = ReceivePort();
    // Rect mask = object.mask;
    // bool maskActive = object.maskActive;

    object.sendPort.send(rP.sendPort);

    int portCapacity = 50;

    rP.listen(
      (message) {
        // MESSAGE FROM MAIN THREAD
        if (message is Map<String, dynamic>) {
          if (message["receivedFrame"] != null) {
            portCapacity++;
          }
        }
        // if (message is Map<String, dynamic>) {
        //   if (message["mTop"] != null &&
        //       message["mLeft"] != null &&
        //       message["mWidth"] != null &&
        //       message["mHeight"] != null) {
        //     mask = Rect.fromLTWH(message["mLeft"]!, message["mTop"]!,
        //         message["mWidth"]!, message["mHeight"]);
        //   }
        //   if (message["mActive"] != null) {
        //     maskActive = message["mActive"]!;
        //   }
        // }
      },
      onDone: () {},
    );

    /*ffi.Pointer<NDIlib_recv_create_v3_t> pCreateSettings = calloc.call<NDIlib_recv_create_v3_t>(1);
    pCreateSettings.ref.color_format = NDIlib_recv_color_format_e.NDIlib_recv_color_format_UYVY_RGBA;
    pCreateSettings.ref.bandwidth = NDIlib_recv_bandwidth_e.NDIlib_recv_bandwidth_highest;
    pCreateSettings.ref.source_to_connect_to = ffi.Pointer.fromAddress(object.pSourceA).cast<ndi_ffi.NDIlib_source_t>()[0];
    pCreateSettings.ref.p_ndi_recv_name = "NDIScopes".toNativeUtf8().cast<Int8>();
    pCreateSettings.ref.allow_video_fields = 0;*/
    ndi_ffi.NDIlib_recv_instance_t pNDIrecv =
        _ndi.NDIlib_recv_create_v3(ffi.nullptr);
    ffi.Pointer<ndi_ffi.NDIlib_source_t> pSource =
        ffi.Pointer.fromAddress(object.pSourceA);
    _ndi.NDIlib_recv_connect(pNDIrecv, pSource);

    ffi.Pointer<ndi_ffi.NDIlib_video_frame_v2_t> pVideoFrame =
        calloc<ndi_ffi.NDIlib_video_frame_v2_t>();
    int width = 0;
    int height = 0;

    int frame = -1;

    while (true) {
      await Future.delayed(
          Duration.zero); // Allow messages from the main thread to be processed
      frame = _ndi.NDIlib_recv_capture_v3(
          pNDIrecv, pVideoFrame, ffi.nullptr, ffi.nullptr, 200);

      if (frame != ndi_ffi.NDIlib_frame_type_e.NDIlib_frame_type_video) {
        continue;
      }
      // print("NDI received frame");
      width = pVideoFrame.ref.xres;
      height = pVideoFrame.ref.yres;

      // TODO could malloc be used instead of calloc since the following CUDA kernel will override all the memory?
      ffi.Pointer<ffi.Uint8> pRGBA = calloc.call<ffi.Uint8>(width * height * 4);

      switch (pVideoFrame.ref.FourCC) {
        case ndi_ffi.NDIlib_FourCC_video_type_e.NDIlib_FourCC_type_UYVY:
          ndiConvert.UYVYToRGBA(width, height, pVideoFrame.ref.p_data, pRGBA);
        case ndi_ffi.NDIlib_FourCC_video_type_e.NDIlib_FourCC_type_BGRA:
          ndiConvert.BGRAToRGBA(width, height, pVideoFrame.ref.p_data, pRGBA);
        default:
          // ignore: avoid_print
          print("unsupported format");
      }

      // var RGBA = pRGBA.asTypedList(width * height * 4);
      // for (int x = 0; x < 1920; x++) {
      //   for (int y = 0; y < 1080; y++) {
      //     int i = (y * 1920 + x) * 4;
      //   }
      // }

      _ndi.NDIlib_recv_free_video_v2(pNDIrecv, pVideoFrame);

      if (portCapacity > 0) {
        portCapacity--;
        object.sendPort.send(<String, int>{
          "width": width,
          "height": height,
          "pRGBA": pRGBA.address,
        });
      } else {
        print("NDI dropped frame");
        calloc.free(pRGBA);
      }
    }
  }
}

class _SMObject {
  SendPort sendPort;
  int? pFindA;
  _SMObject(this.sendPort, this.pFindA);
}

class _FMObject {
  int pSourceA;
  SendPort sendPort;
  // Size scopeSize;
  // Rect mask;
  // bool maskActive;
  _FMObject(this.pSourceA, this.sendPort);
}

/// A class wrapping around the internal [ndi_ffi.NDIlib_source_t] type.
///
/// Access a sources name with the [name] property.
class NDISource {
  ffi.Pointer<ndi_ffi.NDIlib_source_t> source;
  NDISource(this.source);

  /// Access the name of the given NDI source.
  String get name {
    return source.ref.p_ndi_name.cast<Utf8>().toDartString();
  }

  @override
  String toString() {
    return name;
  }
}

class NDIOutputFrame {
  ui.Image iRGBA;
  NDIOutputFrame({required this.iRGBA});
}
