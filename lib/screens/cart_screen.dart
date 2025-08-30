import 'package:arti/services/cart_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
      ),
      body: cart.items.isEmpty
          ? const Center(
              child: Text('Your cart is empty.'),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final cartItem = cart.items[index];
                      return ListTile(
                        leading: Image.network(cartItem.product.imageUrl),
                        title: Text(cartItem.product.name),
                        subtitle: Text(
                            '${cartItem.quantity} x ₹${cartItem.product.price.toStringAsFixed(2)}'),
                        trailing: Text(
                            '₹${(cartItem.quantity * cartItem.product.price).toStringAsFixed(2)}'),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${cart.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: () {
                      // Implement checkout logic
                    },
                    child: const Text('Checkout'),
                  ),
                ),
              ],
            ),
    );
  }
}
