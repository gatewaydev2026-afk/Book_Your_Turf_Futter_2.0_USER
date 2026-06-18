// // widgets/sports_amentites.dart
// import 'package:flutter/material.dart';
// import 'package:flutter_svg/flutter_svg.dart';

// Widget buildAmenitiesAndSportsSection({
//   required BuildContext context,
//   required dynamic turf,
//   required bool isTablet,
// }) {
//   final Map<String, String> sportImages = {
//     "football & cricket": "assets/sports/football2.png",
//     "cricket": "assets/sports/cricket.png",
//     "football": "assets/sports/football2.png",
//     "badminton": "assets/sports/badminton.png",
//     "pickle ball": "assets/sports/pickle3.png",
//     "pickleball": "assets/sports/pickle3.png",
//   };

//   final Map<String, String> amenityIcons = {
//     "parking": "assets/icons/car_parking.svg",
//     "drinking water": "assets/icons/bottle.svg",
//     "water": "assets/icons/bottle.svg",
//     "rest room": "assets/icons/restroom.svg",
//     "restroom": "assets/icons/restroom.svg",
//     "dressing room": "assets/icons/hanger.svg",
//     "cctv": "assets/icons/cctv.svg",
//     "music system": "assets/icons/music.svg",
//     "music": "assets/icons/music.svg",
//     "first aid": "assets/icons/medical_kit.svg",
//     "sports kits": "assets/icons/sports.svg",
//   };

//   String? getSportImage(String sport) {
//     final key = sport.toLowerCase().trim();
//     if (sportImages.containsKey(key)) return sportImages[key];
//     for (final entry in sportImages.entries) {
//       if (key.contains(entry.key) || entry.key.contains(key)) return entry.value;
//     }
//     return null;
//   }

//   String? getAmenityIcon(String amenity) {
//     final key = amenity.toLowerCase().trim();
//     if (amenityIcons.containsKey(key)) return amenityIcons[key];
//     for (final entry in amenityIcons.entries) {
//       if (key.contains(entry.key)) return entry.value;
//     }
//     return null;
//   }

//   // ✅ Fixed: Handle both String and List types for gameType
//   List<String> getGameTypes() {
//     if (turf.gameType == null || turf.gameType.toString().isEmpty) {
//       return ['Contact for details'];
//     }

//     // If gameType is a String
//     if (turf.gameType is String) {
//       String gameTypeStr = turf.gameType as String;
//       if (gameTypeStr.isEmpty) return ['Contact for details'];
//       // Check if it contains comma (multiple sports)
//       if (gameTypeStr.contains(',')) {
//         return gameTypeStr.split(',').map((s) => s.trim()).toList();
//       }
//       return [gameTypeStr];
//     }

//     // If gameType is a List
//     if (turf.gameType is List) {
//       List<dynamic> gameTypeList = turf.gameType as List;
//       if (gameTypeList.isEmpty) return ['Contact for details'];
//       return gameTypeList.map((s) => s.toString().trim()).toList();
//     }

//     return ['Contact for details'];
//   }

//   // ✅ Fixed: Handle different types for facilities
//   List<String> getFacilitiesList() {
//     if (turf.facilities == null) return [];

//     // If facilities is a Map
//     if (turf.facilities is Map) {
//       return turf.facilities!.keys.toList();
//     }

//     // If facilities is a List
//     if (turf.facilities is List) {
//       List<dynamic> facilitiesList = turf.facilities as List;
//       return facilitiesList.map((f) => f.toString()).toList();
//     }

//     // If facilities is a String
//     if (turf.facilities is String) {
//       String facilitiesStr = turf.facilities as String;
//       if (facilitiesStr.contains(',')) {
//         return facilitiesStr.split(',').map((s) => s.trim()).toList();
//       }
//       return [facilitiesStr];
//     }

//     return [];
//   }

//   return Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       // ================= AMENITIES =================
//       if (getFacilitiesList().isNotEmpty) ...[
//         const Text(
//           "Amenities",
//           style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//         ),
//         const SizedBox(height: 16),
//         GridView.builder(
//           shrinkWrap: true,
//           physics: const NeverScrollableScrollPhysics(),
//           itemCount: getFacilitiesList().length,
//           gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//             crossAxisCount: isTablet ? 4 : 3,
//             mainAxisSpacing: 14,
//             crossAxisSpacing: 14,
//             childAspectRatio: 0.99,
//           ),
//           itemBuilder: (context, index) {
//             final amenity = getFacilitiesList()[index];
//             final iconPath = getAmenityIcon(amenity);
//             return Container(
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(20),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.05),
//                     blurRadius: 8,
//                   ),
//                 ],
//               ),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Container(
//                     height: 48,
//                     width: 48,
//                     child: Center(
//                       child: iconPath != null
//                           ? SvgPicture.asset(
//                         iconPath,
//                         height: 28,
//                         width: 28,
//                         placeholderBuilder: (context) =>
//                         const Icon(Icons.miscellaneous_services, size: 28),
//                       )
//                           : const Icon(Icons.miscellaneous_services, size: 28),
//                     ),
//                   ),
//                   const SizedBox(height: 10),
//                   Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 6),
//                     child: Text(
//                       amenity,
//                       textAlign: TextAlign.center,
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         fontSize: 12,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         ),
//         const SizedBox(height: 30),
//       ],

//       // ================= SPORTS =================
//       const Text(
//         "Available Sports",
//         style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//       ),
//       const SizedBox(height: 14),
//       SizedBox(
//         height: 115,
//         child: ListView.builder(
//           scrollDirection: Axis.horizontal,
//           itemCount: getGameTypes().length,
//           itemBuilder: (context, index) {
//             final sport = getGameTypes()[index];
//             final imagePath = getSportImage(sport);
//             return Container(
//               width: 110,
//               margin: const EdgeInsets.only(right: 14),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(20),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.05),
//                     blurRadius: 8,
//                   ),
//                 ],
//               ),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   if (imagePath != null)
//                     Image.asset(
//                       imagePath,
//                       height: 48,
//                       errorBuilder: (_, __, ___) => const Icon(Icons.sports, size: 48),
//                     )
//                   else
//                     const Icon(Icons.sports, size: 48),
//                   const SizedBox(height: 10),
//                   Text(
//                     sport,
//                     textAlign: TextAlign.center,
//                     style: const TextStyle(
//                       fontSize: 13,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         ),
//       ),
//     ],
//   );
// }
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

Widget buildAmenitiesAndSportsSection({
  required BuildContext context,
  required dynamic turf,
  required bool isTablet,
}) {
  final Map<String, String> sportImages = {
    "football & cricket": "assets/sports/human_cricket.png",
    "cricket & football": "assets/sports/human_cricket.png",
    "cricket": "assets/sports/human_cricket.png",
    "football": "assets/sports/human_cricket.png",
    "badminton": "assets/sports/human_badminton.png",
    "pickle ball": "assets/sports/human_pickle.png",
    "pickleball": "assets/sports/human_pickle.png",
  };

  // Home page-ல் உள்ள same colors
  final Map<String, List<Color>> sportColors = {
    "football": [const Color(0xffFF9A9E), const Color(0xffF6416C)],
    "football & cricket": [const Color(0xffFF9A9E), const Color(0xffF6416C)],
    "cricket": [const Color(0xffFF9A9E), const Color(0xffF6416C)],
    "pickleball": [const Color(0xff43CEA2), const Color(0xff185A9D)],
    "pickle ball": [const Color(0xff43CEA2), const Color(0xff185A9D)],
    "badminton": [const Color(0xffFDC830), const Color(0xffF37335)],
  };

  final List<Color> defaultColors = [
    const Color(0xff667eea),
    const Color(0xff764ba2),
  ];

  final Map<String, String> amenityIcons = {
    "parking": "assets/icons/car_parking.svg",
    "drinking water": "assets/icons/bottle.svg",
    "water": "assets/icons/bottle.svg",
    "rest room": "assets/icons/restroom.svg",
    "restroom": "assets/icons/restroom.svg",
    "dressing room": "assets/icons/hanger.svg",
    "cctv": "assets/icons/cctv.svg",
    "music system": "assets/icons/music.svg",
    "music": "assets/icons/music.svg",
    "first aid": "assets/icons/medical_kit.svg",
    "sports kits": "assets/icons/grp_kit.svg",
  };

  String? getSportImage(String sport) {
    final key = sport.toLowerCase().trim();
    if (sportImages.containsKey(key)) return sportImages[key];
    for (final entry in sportImages.entries) {
      if (key.contains(entry.key) || entry.key.contains(key))
        return entry.value;
    }
    return null;
  }

  List<Color> getSportColors(String sport) {
    final key = sport.toLowerCase().trim();
    if (sportColors.containsKey(key)) return sportColors[key]!;
    for (final entry in sportColors.entries) {
      if (key.contains(entry.key) || entry.key.contains(key))
        return entry.value;
    }
    return defaultColors;
  }

  String? getAmenityIcon(String amenity) {
    final key = amenity.toLowerCase().trim();
    if (amenityIcons.containsKey(key)) return amenityIcons[key];
    for (final entry in amenityIcons.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return null;
  }

  List<String> getGameTypes() {
    if (turf.gameType == null || turf.gameType.toString().isEmpty) {
      return ['Contact for details'];
    }
    if (turf.gameType is String) {
      String gameTypeStr = turf.gameType as String;
      if (gameTypeStr.isEmpty) return ['Contact for details'];
      if (gameTypeStr.contains(',')) {
        return gameTypeStr.split(',').map((s) => s.trim()).toList();
      }
      return [gameTypeStr];
    }
    if (turf.gameType is List) {
      List<dynamic> gameTypeList = turf.gameType as List;
      if (gameTypeList.isEmpty) return ['Contact for details'];
      return gameTypeList.map((s) => s.toString().trim()).toList();
    }
    return ['Contact for details'];
  }

List<String> getFacilitiesList() {
  if (turf.facilities == null) return [];

  if (turf.facilities is Map) {
    return List<String>.from(
      turf.facilities!.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key.toString()),
    );
  }

  if (turf.facilities is List) {
    return List<String>.from(
      (turf.facilities as List).map((f) => f.toString()),
    );
  }

  if (turf.facilities is String) {
    String facilitiesStr = turf.facilities as String;

    if (facilitiesStr.trim().isEmpty) return [];

    return facilitiesStr
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  return [];
}
//   List<String> getFacilitiesList() {
//     if (turf.facilities == null) return [];
//     // if (turf.facilities is Map) {
//     //   return turf.facilities!.keys.toList();
//     // }

//     if (turf.facilities is Map) {
//   return turf.facilities!.entries
//       .where((entry) => entry.value == true)
//       .map((entry) => entry.key.toString())
//       .toList();
// }
//     if (turf.facilities is List) {
//       return (turf.facilities as List).map((f) => f.toString()).toList();
//     }
//     if (turf.facilities is String) {
//       String facilitiesStr = turf.facilities as String;
//       if (facilitiesStr.contains(',')) {
//         return facilitiesStr.split(',').map((s) => s.trim()).toList();
//       }
//       return [facilitiesStr];
//     }
//     return [];
//   }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // ================= AMENITIES =================
      if (getFacilitiesList().isNotEmpty) ...[
        const Text(
          "Amenities",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: getFacilitiesList().length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isTablet ? 5 : 4, 
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) {
            final amenity = getFacilitiesList()[index];
            final iconPath = getAmenityIcon(amenity);
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  iconPath != null
                      ? SvgPicture.asset(
                          iconPath,
                          height: 22,
                          width: 22,
                          placeholderBuilder: (_) => const Icon(
                            Icons.miscellaneous_services,
                            size: 22,
                          ),
                        )
                      : const Icon(Icons.wifi, size: 22),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      amenity,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),
      ],

      // ================= SPORTS =================
      const Text(
        "Available Sports",
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 12),

      Builder(
        builder: (context) {
          final sport = getGameTypes().first;
          final imagePath = getSportImage(sport);
          final colors = getSportColors(sport);

          return Container(
            width: double.infinity,
            height: 130,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),

            child: Row(
              children: [
                Expanded(
                  child: Text(
                    sport,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                if (imagePath != null)
                  Image.asset(
                    imagePath,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.sports, size: 90, color: Colors.white),
                  )
                else
                  const Icon(Icons.sports, size: 90, color: Colors.white),
              ],
            ),
          );
        },
      ),
    ],
  );
}
