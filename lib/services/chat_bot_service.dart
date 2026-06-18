// services/chatbot_service.dart
import 'package:get/get.dart';

class ChatbotService extends GetxService {
  final messages = <ChatMessage>[].obs;
  final isTyping = false.obs;

  // book_your_turf Context Data
  final Map<String, dynamic> _context = {};

  @override
  void onInit() {
    super.onInit();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    messages.add(ChatMessage(
      text: "👋 Hi! I'm your book_your_turf assistant!\n\n"
          "I can help you with:\n"
          "• 📍 Finding nearby turfs (within 20km)\n"
          "• 🎯 Booking slots (Advance 50% / Full payment)\n"
          "• 📅 Checking your bookings (Today/Upcoming/Completed)\n"
          "• 💳 Payment & wallet queries\n"
          "• ❌ Cancellation & refunds (6hrs before, 5% charge)\n"
          "• 👤 Profile updates (Name & Photo)\n"
          "• 🔐 Reset password (Email/Phone OTP)\n"
          "• 🌙 Next day slots (Midnight to 6 AM)\n"
          "• ❓ Any app-related questions\n\n"
          "What would you like help with today?",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> sendMessage(String text) async {
    // Add user message
    messages.add(ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    ));

    isTyping.value = true;

    // Simulate thinking delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Generate response based on intent
    final response = _generateResponse(text.toLowerCase().trim());

    isTyping.value = false;

    messages.add(ChatMessage(
      text: response,
      isUser: false,
      timestamp: DateTime.now(),
      action: _extractAction(text),
      actionData: _extractActionData(text),
    ));
  }

  String _generateResponse(String message) {
    // ==================== CANCEL BOOKING (MUST BE FIRST - HIGHEST PRIORITY) ====================
    if (_containsAny(message, ['cancel', 'cancellation', 'refund', 'cancel booking', 'how to cancel', 'cancel my booking'])) {
      if (_containsAny(message, ['policy', 'charge', 'fee', 'rules', 'timing', 'charges'])) {
        return "📋 **Cancellation & Refund Policy:**\n\n"
            "**Cancellation Rules:**\n"
            "• ✅ Cancel up to **6 hours** before slot start time\n"
            "• ❌ **No refund** for:\n"
            "   - Late cancellation (within 6 hours)\n"
            "   - No-show (didn't arrive)\n"
            "   - Partial cancellation\n\n"
            "**Refund Process:**\n"
            "• Refund credited to **app wallet** only\n"
            "• ⏱️ Takes **7-10 business days**\n"
            "• Money cannot be withdrawn to bank\n"
            "• Can be used for future bookings\n\n"
            "**How to Cancel:**\n"
            "1️⃣ Go to **Bookings** tab\n"
            "2️⃣ Find the booking (Today/Upcoming)\n"
            "3️⃣ Tap the **red 'Cancel'** button\n"
            "4️⃣ Confirm cancellation in dialog\n\n"
            "**After Cancellation:**\n"
            "• Slot becomes available for others\n"
            "• Booking moves to 'Cancelled' tab\n"
            "• Refund automatically processed to wallet\n\n"
            "⚠️ **Important:** Advance paid bookings follow same policy.\n\n"
            "Need to cancel a booking? Tap below to go to Bookings.";
      }
      return "🔄 **How to Cancel a Booking:**\n\n"
          "**Steps to Cancel:**\n"
          "1️⃣ Go to **Bookings** tab (bottom center icon)\n"
          "2️⃣ Select **Today** or **Upcoming** tab\n"
          "3️⃣ Find the booking you want to cancel\n"
          "4️⃣ Tap the **red 'Cancel'** button on the booking card\n"
          "5️⃣ Confirm cancellation in the popup dialog\n\n"
          "**What Happens After Cancellation?**\n"
          "• ✅ Booking is cancelled immediately\n"
          "• 💰 Refund credited to your **app wallet**\n"
          "• ⏱️ Refund takes **7-10 business days**\n"
          "• 📋 Booking moves to 'Cancelled' tab\n\n"
          "**Cancellation Rules:**\n"
          "• Cancel up to **6 hours** before slot time\n"
          "• **5% cancellation charge** applies\n"
          "• No refund for late cancellation or no-show\n\n"
          "**Cannot Cancel If:**\n"
          "• Less than 6 hours before slot\n"
          "• Booking already completed\n"
          "• Slot time has passed\n\n"
          "Want to cancel a booking? Tap below to view your bookings.";
    }

    // ==================== BOOKING (MUST CHECK AFTER CANCEL) ====================
    if (_containsAny(message, ['book', 'booking', 'reserve', 'slot', 'turf', 'court', 'how to book'])) {
      if (_containsAny(message, ['how', 'guide', 'help', 'steps', 'process', 'explain'])) {
        return "🎯 **Complete Booking Guide:**\n\n"
            "**Step 1: Find a Turf**\n"
            "• Open **Home** tab (bottom left)\n"
            "• Browse turfs within **20km** of your location\n"
            "• Use **search** to filter by name/location/sport\n"
            "• Tap on any turf card to view details\n\n"
            "**Step 2: Select Date & Court**\n"
            "• Choose a **date** (up to 60 days in advance)\n"
            "• Select **Court/Turf** number (if multiple)\n"
            "• Check operating hours ⏰\n\n"
            "**Step 3: Choose Time Slots**\n"
            "• **Available** slots: Green border, white background\n"
            "• **Booked** slots: Red (unavailable)\n"
            "• **Next Day** slots: Purple badge (midnight to 6 AM)\n"
            "• Tap multiple slots to select\n\n"
            "**Step 4: Payment Options**\n"
            "• **Advance (50%)** - Pay half now, rest at venue\n"
            "• **Full Payment** - Pay entire amount now\n"
            "• Wallet balance auto-applies\n\n"
            "**Step 5: Confirm Booking**\n"
            "• Review booking summary\n"
            "• Tap **'Make Payment'**\n"
            "• Complete via Razorpay (GPay/UPI/Card)\n\n"
            "**Step 6: Get Confirmation**\n"
            "• Instant confirmation in app\n"
            "• Email & SMS received\n"
            "• View in **Bookings** tab\n\n"
            "✨ **Pro Tip:** Book advance slots to get best timings!\n\n"
            "Ready to book? Tap below to browse turfs.";
      }
      return "🎯 **Quick Booking:**\n\n"
          "**To book a turf:**\n"
          "1️⃣ **Home** tab → Tap any turf\n"
          "2️⃣ Select **Date** & **Court/Turf**\n"
          "3️⃣ Choose **time slots** (tap to select)\n"
          "4️⃣ Pick **Payment type** (Advance 50% / Full)\n"
          "5️⃣ Tap **'Confirm Booking'**\n"
          "6️⃣ Complete payment via Razorpay\n\n"
          "✅ Booking confirmed instantly!\n"
          "📧 Confirmation sent to email/SMS\n\n"
          "**Supported Payments:**\n"
          "• Google Pay / PhonePe / UPI\n"
          "• Credit/Debit Cards\n"
          "• Netbanking\n"
          "• Wallet balance\n\n"
          "Want to see all available turfs? Tap below to go to Home.";
    }

    // ==================== RESET PASSWORD ====================
    if (_containsAny(message, ['forgot password', 'reset password', 'change password', 'password reset', 'forgot my password', "can't login"])) {
      return "🔐 **Reset Your Password:**\n\n"
          "**Step-by-step guide:**\n\n"
          "1️⃣ Go to **Login** screen\n"
          "2️⃣ Tap **'Forgot Password?'** button\n"
          "3️⃣ Choose verification method:\n"
          "   • 📧 **Email** - OTP sent to registered email\n"
          "   • 📱 **Phone** - OTP sent via SMS\n"
          "4️⃣ Enter the **6-digit OTP**\n"
          "5️⃣ Create a **new password** (minimum 6 characters)\n"
          "6️⃣ Confirm your new password\n\n"
          "✅ **Password updated immediately!**\n\n"
          "⚠️ **Tips:**\n"
          "• Use a strong password (letters + numbers)\n"
          "• Don't share your password with anyone\n"
          "• OTP expires in 5 minutes\n\n"
          "Need to reset now? Tap below to go to Forgot Password screen.";
    }

    // ==================== NEXT DAY SLOTS ====================
    if (_containsAny(message, ['next day', 'midnight slot', 'after midnight', 'early morning', '12 am slot', '1 am slot', 'late night slot'])) {
      return "🌙 **Next Day Slots Explained:**\n\n"
          "**What are Next Day Slots?**\n"
          "Slots that start after midnight (12:00 AM to 6:00 AM) but belong to your selected date.\n\n"
          "**Example:**\n"
          "• You select **June 1** as booking date\n"
          "• A slot showing **1:00 AM - 2:00 AM** with 'Next Day' badge\n"
          "• This slot is actually for **June 2, 1:00 AM**\n\n"
          "**Visual Indicators:**\n"
          "• 🟣 **Purple badge** with 'Next Day' text\n"
          "• Purple border around the slot\n"
          "• Time is shown in 12-hour format\n\n"
          "**Why this system?**\n"
          "• Easy to book late-night/early-morning sessions\n"
          "• No confusion about date boundaries\n"
          "• Perfect for night owls and early birds!\n\n"
          "**Available Slots:**\n"
          "• 12:00 AM - 1:00 AM\n"
          "• 1:00 AM - 2:00 AM\n"
          "• 2:00 AM - 3:00 AM\n"
          "• 3:00 AM - 4:00 AM\n"
          "• 4:00 AM - 5:00 AM\n"
          "• 5:00 AM - 6:00 AM\n\n"
          "_Note: Venue must be open during these hours_";
    }

    // ==================== MY BOOKINGS ====================
    if (_containsAny(message, ['my booking', 'my bookings', 'booking history', 'past bookings', 'upcoming bookings', 'booking list'])) {
      return "📋 **Your Bookings Dashboard:**\n\n"
          "**How to View:**\n"
          "• Tap **Bookings** tab (bottom center, middle icon)\n\n"
          "**Booking Categories:**\n"
          "• 📅 **Today** - Bookings for current day\n"
          "• ⏰ **Upcoming** - Future bookings\n"
          "• ✅ **Completed** - Past finished bookings\n"
          "• ❌ **Cancelled** - Cancelled bookings\n\n"
          "**Filter Options:**\n"
          "• **Date filters:** Today, Tomorrow, This Week, This Month, Custom\n"
          "• **Payment status:** All, Pending, Advance Paid, Fully Paid\n"
          "• **Clear All** button to reset filters\n\n"
          "**Booking Card Info:**\n"
          "• Turf name & game type\n"
          "• Date, Court/Turf number\n"
          "• Slots with times (purple = Next Day slots)\n"
          "• Payment progress (circular indicator)\n"
          "• **Pay Balance** button for advance bookings\n\n"
          "**Statistics:**\n"
          "• Tap **bar chart icon** (📊) to see stats\n\n"
          "Would you like to view your bookings now?";
    }

    // ==================== WALLET ====================
    if (_containsAny(message, ['wallet', 'balance', 'money in wallet', 'check balance', 'wallet balance'])) {
      return "💰 **Your Wallet:**\n\n"
          "**How to check balance:**\n"
          "1️⃣ Go to **Dashboard** tab (bottom right)\n"
          "2️⃣ Look at the **Wallet Card** (green gradient)\n"
          "3️⃣ Your balance is shown in **₹**\n"
          "4️⃣ Tap the **refresh icon** (↻) to update\n\n"
          "**Using Wallet for Bookings:**\n"
          "• Wallet balance auto-applies during checkout\n"
          "• Can be combined with other payment methods\n"
          "• Full refunds go to wallet\n\n"
          "Your current wallet balance is shown on your Dashboard.";
    }

    // ==================== COINS CONVERSION ====================
    if (_containsAny(message, ['convert coins', 'redeem points', 'coins to wallet', 'points to wallet', 'game coins'])) {
      return "🎮 **Convert Game Coins to Wallet:**\n\n"
          "**How to Convert:**\n"
          "1️⃣ Go to **Dashboard** tab (bottom right)\n"
          "2️⃣ On the **Wallet Card**, tap **'Redeem Points'**\n"
          "3️⃣ Enter number of coins (minimum **200 coins**)\n"
          "4️⃣ Tap **'Convert'** button\n\n"
          "**Conversion Rate:**\n"
          "• 100 coins = ₹10\n"
          "• Minimum 200 coins to redeem\n"
          "• Instant credit to wallet\n\n"
          "**How to Earn Coins:**\n"
          "• 🎁 **Referral:** Invite friends → 10 coins each\n"
          "• 📅 **Daily Check-in:** Coming soon\n"
          "• 🎯 **Special Offers:** Watch for notifications\n\n"
          "Your current coins are shown on Dashboard > Wallet Card";
    }

    // ==================== FAVORITES ====================
    if (_containsAny(message, ['favorite', 'favourites', 'saved turfs', 'like', 'heart', 'wishlist'])) {
      return "❤️ **Favorites / Wishlist:**\n\n"
          "**How to Add to Favorites:**\n"
          "• On **Home** screen, tap the **heart icon** (❤️) on any turf card\n"
          "• Heart turns **red** → Added to favorites\n"
          "• Tap again to remove\n\n"
          "**How to View Favorites:**\n"
          "1️⃣ Go to **Dashboard** tab\n"
          "2️⃣ Tap **'Favorite Turfs'** in the menu\n"
          "3️⃣ All your saved turfs appear in a grid\n\n"
          "**Features:**\n"
          "• Save unlimited turfs\n"
          "• Quick access to book again\n"
          "• Syncs with your account\n\n"
          "Would you like to view your favorites now?";
    }

    // ==================== REFERRAL ====================
    if (_containsAny(message, ['refer', 'referral', 'invite', 'share app', 'earn points', 'referral code'])) {
      return "🎁 **Refer & Earn Program:**\n\n"
          "**How it Works:**\n"
          "1️⃣ Go to **Dashboard** tab\n"
          "2️⃣ Find the **'REFER & EARN!'** card\n"
          "3️⃣ Copy your **unique referral code**\n"
          "4️⃣ Share with friends via WhatsApp, SMS, etc.\n"
          "5️⃣ Friend uses code during signup\n"
          "6️⃣ **Both get 10 Game Coins!** 🎉\n\n"
          "**Rewards:**\n"
          "• 🎮 **10 Game Coins** for you\n"
          "• 🎮 **10 Game Coins** for your friend\n"
          "• No limit on referrals!\n\n"
          "**Where to Find Your Code:**\n"
          "Dashboard → Refer & Earn card → Your unique code shown\n\n"
          "Start inviting now and earn unlimited coins! 🚀";
    }

    // ==================== PROFILE ====================
    if (_containsAny(message, ['profile', 'account', 'edit profile', 'update name', 'change photo', 'my name', 'profile picture'])) {
      return "👤 **Profile Management:**\n\n"
          "**How to Update Profile:**\n"
          "1️⃣ Go to **Dashboard** tab (bottom right)\n"
          "2️⃣ Tap the **edit icon** (✏️) in the top right\n"
          "3️⃣ Update your **Full Name**\n"
          "4️⃣ Tap the profile image to **change photo**\n"
          "   • Choose from **Gallery**\n"
          "   • Take a **photo** with Camera\n"
          "5️⃣ Tap **'Save Changes'**\n\n"
          "**What You Can Change:**\n"
          "• ✅ **Full Name** - Editable\n"
          "• ✅ **Profile Picture** - Upload from gallery/camera\n"
          "• ❌ **Email** - Locked (contact support to change)\n"
          "• ❌ **Phone Number** - Locked (for security)\n\n"
          "Want to update your profile? Tap below to go to Dashboard.";
    }

    // ==================== LOCATION / NEARBY ====================
    if (_containsAny(message, ['location', 'nearby', 'distance', 'near me', 'close to me', 'find near me'])) {
      return "📍 **Location & Nearby Turfs:**\n\n"
          "**How Location Works:**\n"
          "• App automatically detects your GPS location\n"
          "• Shows turfs within **20km radius** only\n"
          "• Turfs sorted by **distance** (closest first)\n"
          "• Distance shown on each turf card\n\n"
          "**Location Requirements:**\n"
          "• **Enable GPS/Location** on your phone\n"
          "• **Allow permission** when app asks\n"
          "• Both WiFi and mobile data work\n\n"
          "**What You See:**\n"
          "• Your current location at top of Home page\n"
          "• Example: 'KK Nagar, Madurai'\n"
          "• Tap location to open Google Maps\n"
          "• 🔄 Pull down to refresh nearby turfs\n\n"
          "Your current location is shown on the Home screen.";
    }

    // ==================== PAYMENT OPTIONS ====================
    if (_containsAny(message, ['payment', 'pay', 'pay now', 'payment options', 'how to pay', 'payment methods'])) {
      return "💳 **Payment Options & Methods:**\n\n"
          "**Supported Payment Gateways (Razorpay):**\n"
          "• 📱 **UPI Apps:** Google Pay, PhonePe, Paytm\n"
          "• 💳 **Cards:** Credit/Debit Cards (Visa, Mastercard, RuPay)\n"
          "• 🏦 **Netbanking:** All major banks\n"
          "• 💰 **Wallet:** App wallet balance\n\n"
          "**Payment Types:**\n"
          "• **Advance (50%)** 💚 - Pay 50% now, 50% at venue\n"
          "• **Full Payment** 💚 - Pay 100% online\n\n"
          "**How to Pay:**\n"
          "1. Select slots\n"
          "2. Choose payment type\n"
          "3. Tap **'Make Payment'**\n"
          "4. Razorpay popup opens\n"
          "5. Complete payment\n"
          "6. Instant confirmation\n\n"
          "**Security:** 🔒 PCI-DSS compliant, no card details stored";
    }

    // ==================== SUPPORT / HELP ====================
    if (_containsAny(message, ['help', 'support', 'contact', 'customer care', 'issue', 'problem', 'complaint', 'not working', 'error'])) {
      return "📞 **Customer Support & Help:**\n\n"
          "**Contact Methods:**\n"
          "• 📧 **Email:** support@book_your_turf.net\n"
          "• 📞 **Phone:** +91 9566001173\n"
          "• 🏢 **Customer Care:** +91 9940663099\n"
          "• 💬 **Chatbot** - You're already here!\n\n"
          "**Support Hours:**\n"
          "• Monday - Saturday: 9 AM to 9 PM\n"
          "• Sunday: 10 AM to 6 PM\n\n"
          "**Common Issues:**\n\n"
          "**Payment Failed?**\n"
          "• Check internet connection\n"
          "• Try different payment method\n"
          "• Money deducted but no booking? Tap 'Yes, I Paid'\n\n"
          "**Login Issues?**\n"
          "• Use 'Forgot Password' to reset\n"
          "• Check email/phone correctly\n\n"
          "Need immediate help? Call or email us during business hours.";
    }

    // ==================== TERMS & PRIVACY ====================
    if (_containsAny(message, ['term', 'policy', 'privacy', 'condition', 'legal', 'terms and conditions', 'privacy policy'])) {
      if (_containsAny(message, ['privacy', 'data', 'information'])) {
        return "📄 **Privacy Policy Summary:**\n\n"
            "**Information We Collect:**\n"
            "• Personal: Name, Email, Phone Number\n"
            "• Booking: Turf schedules, Transaction history\n"
            "• Location: To show nearby venues\n"
            "• Device: OS type, app usage, IP address\n\n"
            "**How We Use Your Data:**\n"
            "• Process bookings and payments\n"
            "• Show nearby venues based on location\n"
            "• Send booking confirmations\n\n"
            "**Payment Security:**\n"
            "• PCI-DSS compliant\n"
            "• No card details stored locally\n"
            "• Secure third-party gateways\n\n"
            "**Full Privacy Policy** is available in Dashboard → App Info\n\n"
            "Would you like to open the complete Privacy Policy?";
      }
      return "📄 **Terms & Conditions Summary:**\n\n"
          "**Booking Policy:**\n"
          "• Bookings confirmed after payment\n"
          "• Arrive 10-15 minutes before slot\n"
          "• Playtime starts and ends as per schedule\n\n"
          "**Payment Terms:**\n"
          "• Advance (50%) or Full payment\n"
          "• Prices include taxes\n\n"
          "**Cancellation & Refund:**\n"
          "• Cancel up to 6 hours before\n"
          "• 5% cancellation charge\n"
          "• No refund for no-shows\n"
          "• Refunds take 7-10 business days\n\n"
          "**Full Terms & Conditions** available in Dashboard → App Info\n\n"
          "Would you like to open the complete Terms & Conditions?";
    }

    // ==================== ABOUT APP ====================
    if (_containsAny(message, ['about app', 'about book_your_turf', 'what is this app', 'app features', 'tell me about this app'])) {
      return "📱 **About book_your_turf:**\n\n"
          "**What is book_your_turf?**\n"
          "A smart sports booking platform for players and teams!\n\n"
          "**Supported Sports:** 🏏⚽🏸\n"
          "• Cricket & Football\n"
          "• Badminton\n"
          "• Pickleball\n"
          "• Coming soon: Tennis, Basketball, Swimming\n\n"
          "**Key Features:**\n"
          "• 📍 Find venues within 20km\n"
          "• 🎯 Real-time slot availability\n"
          "• 💰 Transparent pricing\n"
          "• ✅ Instant booking confirmation\n"
          "• 💳 Online payment & Pay at venue\n"
          "• 📋 Booking history\n"
          "• ❌ Easy cancellation\n"
          "• 🎁 Referral rewards\n\n"
          "**App Version:** 2.0\n"
          "**Owned by:** NOTTAM INFOTECH PRIVATE LIMITED";
    }

    // ==================== GREETINGS ====================
    if (_containsAny(message, ['hello', 'hi', 'hey', 'greetings', 'good morning', 'good evening', 'good afternoon', 'namaste'])) {
      return "👋 Hello! Welcome to book_your_turf!\n\n"
          "I'm your personal assistant for sports venue booking.\n\n"
          "**I can help you with:**\n"
          "• 📍 Finding turfs near you (within 20km)\n"
          "• 🎯 Booking slots (Advance/Full payment)\n"
          "• 📋 Managing your bookings\n"
          "• 💳 Payments and wallet\n"
          "• ❌ Cancellations and refunds\n"
          "• 🔐 Password reset\n"
          "• 👤 Profile updates\n"
          "• 🌙 Next day slots\n"
          "• 🎁 Referral rewards\n\n"
          "**Quick Commands:**\n"
          "• 'How to book' - Complete booking guide\n"
          "• 'My bookings' - View all your bookings\n"
          "• 'Cancel policy' - Cancellation rules\n"
          "• 'Reset password' - Step-by-step guide\n"
          "• 'Next day slots' - Late night booking info\n\n"
          "What would you like to do today? 🚀";
    }

    // ==================== THANK YOU ====================
    if (_containsAny(message, ['thank', 'thanks', 'appreciate', 'helpful', 'good', 'great', 'awesome'])) {
      return "🙏 You're most welcome!\n\n"
          "I'm thrilled I could help you! 😊\n\n"
          "**Is there anything else you need?**\n\n"
          "You can ask me about:\n"
          "• 📖 **How to book** - Complete guide\n"
          "• 📋 **My bookings** - Check status\n"
          "• ❌ **Cancel booking** - Policy & steps\n"
          "• 💳 **Payment** - Methods & options\n"
          "• 🔐 **Reset password** - Forgot login\n"
          "• 🌙 **Next day slots** - Late night booking\n"
          "• 🎁 **Referral** - Earn free coins\n"
          "• 📞 **Contact support** - Get help\n\n"
          "Enjoy your game! 🏏⚽🏸\n\n"
          "What would you like to explore next?";
    }

    // ==================== DEFAULT FALLBACK ====================
    return "🤔 I want to help, but I'm not sure I understand.\n\n"
        "**Here's everything I can help you with:**\n\n"
        "**📍 Finding & Booking**\n"
        "• 'Find turfs near me' - Show nearby venues\n"
        "• 'How to book' - Complete booking guide\n"
        "• 'Next day slots' - Late night booking info\n\n"
        "**📋 Managing Bookings**\n"
        "• 'My bookings' - View your bookings\n"
        "• 'Cancel booking' - How to cancel\n"
        "• 'Cancel policy' - Rules & refunds\n\n"
        "**💰 Payments & Wallet**\n"
        "• 'Payment options' - All payment methods\n"
        "• 'Wallet balance' - Check balance\n"
        "• 'Convert coins' - Redeem game coins\n\n"
        "**👤 Account Settings**\n"
        "• 'Edit profile' - Update name/photo\n"
        "• 'Reset password' - Forgot password help\n"
        "• 'Referral code' - Invite & earn\n"
        "• 'Favorites' - Save turfs\n\n"
        "**ℹ️ App Information**\n"
        "• 'About app' - App features\n"
        "• 'Privacy policy' - Data handling\n"
        "• 'Terms and conditions' - Rules\n"
        "• 'Contact support' - Get help\n\n"
        "**Try asking:**\n"
        "• 'How to book a turf?'\n"
        "• 'Show me my bookings'\n"
        "• 'Cancel my booking'\n"
        "• 'Reset my password'\n"
        "• 'What are next day slots?'\n\n"
        "What would you like help with? Type your question above! 💬";
  }

  bool _containsAny(String message, List<String> keywords) {
    return keywords.any((keyword) => message.contains(keyword));
  }

  String? _extractAction(String message) {
    final lower = message.toLowerCase();

    // Cancel takes highest priority
    if (_containsAny(lower, ['cancel', 'cancellation', 'cancel booking', 'how to cancel'])) {
      return 'navigate_to_bookings';
    }

    if (_containsAny(lower, ['book', 'booking', 'reserve', 'slot', 'turf', 'browse turfs', 'find turfs'])) {
      return 'navigate_to_home';
    }
    if (_containsAny(lower, ['my booking', 'my bookings', 'booking history', 'view bookings'])) {
      return 'navigate_to_bookings';
    }
    if (_containsAny(lower, ['profile', 'account', 'edit profile', 'dashboard', 'wallet', 'coins', 'referral'])) {
      return 'navigate_to_profile';
    }
    if (_containsAny(lower, ['favorite', 'favourites', 'saved turfs', 'wishlist'])) {
      return 'navigate_to_favorites';
    }
    if (_containsAny(lower, ['privacy policy', 'privacy', 'data privacy'])) {
      return 'open_privacy_policy';
    }
    if (_containsAny(lower, ['terms', 'terms and conditions', 'condition', 't&c'])) {
      return 'open_terms_conditions';
    }
    if (_containsAny(lower, ['forgot password', 'reset password', 'change password'])) {
      return 'navigate_to_forgot_password';
    }
    if (_containsAny(lower, ['about app', 'app info', 'about book_your_turf'])) {
      return 'navigate_to_about';
    }
    return null;
  }

  Map<String, dynamic>? _extractActionData(String message) {
    final lower = message.toLowerCase();

    if (_containsAny(lower, ['privacy policy', 'privacy'])) {
      return {'screen': 'privacy_policy'};
    }
    if (_containsAny(lower, ['terms', 'terms and conditions', 'condition', 't&c'])) {
      return {'screen': 'terms_conditions'};
    }
    if (_containsAny(lower, ['forgot password', 'reset password'])) {
      return {'screen': 'forgot_password'};
    }
    if (_containsAny(lower, ['about app', 'app info'])) {
      return {'screen': 'about_us'};
    }
    return null;
  }

  void clearContext() {
    _context.clear();
  }

  void addContext(String key, dynamic value) {
    _context[key] = value;
  }

  void clearMessages() {
    messages.clear();
    _addWelcomeMessage();
  }
}

// models/chat_message.dart
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? action;
  final Map<String, dynamic>? actionData;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.action,
    this.actionData,
  });
}