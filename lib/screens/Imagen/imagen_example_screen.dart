import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'imagen_vertex_service.dart';

class ImagenExampleScreen extends StatefulWidget {
	const ImagenExampleScreen({super.key});

	@override
	State<ImagenExampleScreen> createState() => _ImagenExampleScreenState();
}

class _ImagenExampleScreenState extends State<ImagenExampleScreen> {
	static const platform = MethodChannel('com.local.artsisans/gemini');
	final _picker = ImagePicker();

	Uint8List? _bytes;
	String _prompt = '';
	String _nano = '';
	String _url = '';
	bool _loading = false;

	final _imagen = ImagenVertexService(
		location: 'us-central1',
		model: 'imagen-2.0',
	);

	@override
	void initState() {
		super.initState();
		Firebase.initializeApp();
	}

	Future<void> _pick() async {
		final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 92);
		if (x == null) return;
		final b = await x.readAsBytes();
		setState(() {
			_bytes = b;
			_nano = '';
		});
	}

	Future<void> _suggestWithNano() async {
		if (_bytes == null) return;
		setState(() => _loading = true);
		try {
			final res = await platform.invokeMethod<String>('describeImageWithNano', {
				'imageBase64': base64Encode(_bytes!),
			});
			setState(() {
				_nano = res ?? '';
				if (_prompt.isEmpty) _prompt = _nano;
			});
		} on PlatformException catch (e) {
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('Nano error: ${e.message}')),
			);
		} finally {
			setState(() => _loading = false);
		}
	}

	Future<void> _generate() async {
		if (_bytes == null || _prompt.trim().isEmpty) return;
		setState(() => _loading = true);
		try {
			final path = 'generated/imgen_${DateTime.now().millisecondsSinceEpoch}.png';
			final url = await _imagen.editAndUpload(
				sourceImage: _bytes!,
				prompt: _prompt.trim(),
				storagePath: path,
			);
			setState(() => _url = url);
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Generated and uploaded')),
			);

			// If opened as a dialog/page expecting a result, pop with URL
			if (Navigator.canPop(context)) {
				// keep screen; don't auto-pop unless used modally
			}
		} catch (e) {
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('Imagen failed: $e')),
			);
		} finally {
			setState(() => _loading = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Enhance with Imagen 2'),
				actions: [
					if (_url.isNotEmpty)
						TextButton(
							onPressed: () => Navigator.of(context).pop(_url),
							child: const Text('Use Image', style: TextStyle(color: Colors.white)),
						)
				],
			),
			body: SingleChildScrollView(
				padding: const EdgeInsets.all(16),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Container(
							width: double.infinity,
							height: 220,
							decoration: BoxDecoration(
								color: Colors.grey.shade200,
								borderRadius: BorderRadius.circular(12),
							),
							child: _bytes == null
									? const Center(child: Text('No image selected'))
									: ClipRRect(
											borderRadius: BorderRadius.circular(12),
											child: Image.memory(_bytes!, fit: BoxFit.cover),
										),
						),
						const SizedBox(height: 12),
						Row(
							children: [
								ElevatedButton.icon(
									onPressed: _pick,
									icon: const Icon(Icons.photo),
									label: const Text('Pick Image'),
								),
								const SizedBox(width: 12),
								ElevatedButton(
									onPressed: _loading ? null : _suggestWithNano,
									child: const Text('Suggest with Nano'),
								),
							],
						),
						const SizedBox(height: 16),
						TextField(
							minLines: 1,
							maxLines: 4,
							decoration: const InputDecoration(
								labelText: 'Prompt',
								hintText: 'Describe edit or style to apply',
							),
							controller: TextEditingController(text: _prompt),
							onChanged: (v) => _prompt = v,
						),
						if (_nano.isNotEmpty) ...[
							const SizedBox(height: 8),
							const Text('Nano suggestion:', style: TextStyle(fontWeight: FontWeight.w600)),
							Text(_nano),
						],
						const SizedBox(height: 12),
						ElevatedButton.icon(
							onPressed: _loading ? null : _generate,
							icon: const Icon(Icons.auto_awesome),
							label: const Text('Generate with Imagen'),
						),
						if (_loading) const Padding(
							padding: EdgeInsets.only(top: 16),
							child: Center(child: CircularProgressIndicator()),
						),
						if (_url.isNotEmpty) ...[
							const SizedBox(height: 16),
							const Text('Result:'),
							const SizedBox(height: 8),
							ClipRRect(
								borderRadius: BorderRadius.circular(12),
								child: Image.network(_url),
							),
						],
					],
				),
			),
		);
	}
}

