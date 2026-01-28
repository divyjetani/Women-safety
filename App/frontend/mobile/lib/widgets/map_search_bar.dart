import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/place_search_service.dart';

class MapSearchBar extends StatelessWidget {
  final ValueChanged<LatLng> onPlaceSelected;

  const MapSearchBar({super.key, required this.onPlaceSelected});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(14),
        child: TypeAheadField<PlaceResult>(
          debounceDuration: const Duration(milliseconds: 300),
          suggestionsCallback: PlaceSearchService.searchNearby,
          itemBuilder: (_, place) => ListTile(
            title: Text(place.name),
            subtitle: Text(place.address),
          ),
          onSelected: (place) {
            onPlaceSelected(LatLng(place.lat, place.lng));
          },
          builder: (_, controller, focusNode) {
            return TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                hintText: "Search area or place",
                prefixIcon: Icon(Icons.search),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
              ),
            );
          },
        ),
      ),
    );
  }
}
