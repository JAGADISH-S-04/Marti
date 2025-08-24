import 'package:arti/models/product.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Product>> getProducts() {
    return _db.collection('products').snapshots().map((snapshot) => snapshot
        .docs
        .map((doc) => Product(
              id: doc.id,
              name: doc['name'],
              description: doc['description'],
              price: doc['price'],
              imageUrl: doc['imageUrl'], artisanId: '', category: '', materials: [], craftingTime: '', dimensions: '', imageUrls: [], createdAt: DateTime.now(), stockQuantity: 0, tags: [],
            ))
        .toList());
  }
}
