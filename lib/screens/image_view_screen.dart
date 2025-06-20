import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class ImageViewScreen extends StatelessWidget {
  final dynamic image;

  const ImageViewScreen({
    super.key,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 40),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: image is Uint8List
              ? Image.memory(
                  image as Uint8List,
                  fit: BoxFit.contain,
                )
              : image is File
                  ? Image.file(
                      image as File,
                      fit: BoxFit.contain,
                    )
                  : Image.network(
                      image.toString(),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Text(
                            'Ошибка загрузки изображения',
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
} 