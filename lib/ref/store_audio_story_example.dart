// Example of how store data would look with audio story features:
// This shows what the Firebase store document would contain

final Map<String, dynamic> exampleStoreWithAudioStory = {
  'storeName': 'Traditional Crafts by Rajesh',
  'storeDescription': 'Authentic handmade crafts from Rajasthan',
  'storeType': 'Handicrafts',
  'contactNumber': '9876543210',
  'upiId': 'rajesh@upi',
  'imageUrl': 'https://example.com/store-image.jpg',
  'sellerId': 'seller123',
  'sellerEmail': 'rajesh@example.com',
  'rating': 4.5,
  'isActive': true,
  'totalProducts': 25,
  'createdAt': DateTime.now().millisecondsSinceEpoch,
  
  // Audio Story Fields (new additions)
  'audioStoryUrl': 'https://firebasestorage.googleapis.com/audio-stories/store-rajesh-story.m4a',
  'audioStoryTranscription': '''
    Namaste! My name is Rajesh Kumar, and I have been creating traditional Rajasthani handicrafts for over 25 years. 
    
    My journey began when I was just 12 years old, learning from my father who was also a master craftsman. We specialize in hand-painted pottery, intricate mirror work, and beautiful textiles that tell the stories of our rich cultural heritage.
    
    Each piece we create is not just a product, but a piece of history passed down through generations. When you buy from us, you're not just purchasing an item - you're supporting a family tradition and helping preserve our ancient arts.
    
    We use only natural materials sourced from local artisans in our village. Every stroke of paint, every stitch, and every mirror is placed with love and respect for our craft.
    
    Thank you for visiting our store, and I hope our creations bring joy and beauty to your home.
  ''',
  'audioStoryTranslations': {
    'hindi': '''
      नमस्ते! मेरा नाम राजेश कुमार है, और मैं 25 से अधिक वर्षों से पारंपरिक राजस्थानी हस्तशिल्प बना रहा हूं।
      
      मेरी यात्रा तब शुरू हुई जब मैं केवल 12 साल का था, अपने पिता से सीख रहा था जो भी एक मास्टर शिल्पकार थे। हम हाथ से पेंट की गई मिट्टी के बर्तन, जटिल दर्पण कार्य, और सुंदर वस्त्रों में विशेषज्ञ हैं जो हमारी समृद्ध सांस्कृतिक विरासत की कहानियां कहते हैं।
      
      हमारी हर कृति केवल एक उत्पाद नहीं है, बल्कि पीढ़ियों से चली आ रही इतिहास का एक टुकड़ा है। जब आप हमसे खरीदते हैं, तो आप केवल एक वस्तु नहीं खरीद रहे - आप एक पारिवारिक परंपरा का समर्थन कर रहे हैं और हमारी प्राचीन कलाओं को संरक्षित करने में मदद कर रहे हैं।
    ''',
    'english': '''
      Hello! My name is Rajesh Kumar, and I have been creating traditional Rajasthani handicrafts for over 25 years.
      
      My journey began when I was just 12 years old, learning from my father who was also a master craftsman. We specialize in hand-painted pottery, intricate mirror work, and beautiful textiles that tell the stories of our rich cultural heritage.
      
      Each piece we create is not just a product, but a piece of history passed down through generations. When you buy from us, you're not just purchasing an item - you're supporting a family tradition and helping preserve our ancient arts.
    ''',
    'bengali': '''
      নমস্কার! আমার নাম রাজেশ কুমার, এবং আমি ২৫ বছরেরও বেশি সময় ধরে ঐতিহ্যবাহী রাজস্থানী হস্তশিল্প তৈরি করে আসছি।
      
      আমার যাত্রা শুরু হয়েছিল যখন আমি মাত্র ১২ বছর বয়সে ছিলাম, আমার বাবার কাছ থেকে শিখেছিলাম যিনি একজন মাস্টার কারিগরও ছিলেন। আমরা হাতে আঁকা মৃৎশিল্প, জটিল আয়না কাজ, এবং সুন্দর বস্ত্রে বিশেষজ্ঞ যা আমাদের সমৃদ্ধ সাংস্কৃতিক ঐতিহ্যের গল্প বলে।
    '''
  }
};

// Example showing how to add audio story to existing store
// This would be done through a seller interface or admin panel

/*
To add audio story to store in Firebase:

1. Upload audio file to Firebase Storage
2. Get transcription using Gemini AI service  
3. Get translations for multiple languages
4. Update store document with:
   - audioStoryUrl
   - audioStoryTranscription  
   - audioStoryTranslations

Firebase update example:
await FirebaseFirestore.instance
  .collection('stores')
  .doc(storeId)
  .update({
    'audioStoryUrl': audioUrl,
    'audioStoryTranscription': transcription,
    'audioStoryTranslations': translations,
  });
*/
