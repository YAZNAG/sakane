
import 'package:flutter/material.dart';
import 'package:immobilier/models/realestate.dart';

class RealestateWidget extends StatelessWidget {
  final Realestate realestate;
  final void Function(Realestate)? onClick;
  final void Function(Realestate)? onLondClick;
  final void Function(Realestate)? onDelete;
  const RealestateWidget({super.key, required this.realestate, this.onClick, this.onLondClick, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final imageUrl = realestate.media != null && realestate.media!.isNotEmpty
        ? realestate.media!.first.url
        : null;
    return GestureDetector(
      onTap: ()=>onClick?.call(realestate),
      onLongPress: ()=>onLondClick?.call(realestate),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.broken_image, size: 50, color: Colors.grey);
                    },
                  ),
                )
              else
                Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey[300],
                  child: Icon(Icons.image, size: 40, color: Colors.grey[600]),
                ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            realestate.title ?? '',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (onDelete != null)
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 22),
                            tooltip: 'Supprimer',
                            onPressed: () => onDelete!(realestate),
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      realestate.description ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 18),
                        SizedBox(width: 4),
                        Text(
                          (realestate.rate ?? 0).toString(),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 8),
                        Text('(${realestate.rateCount ?? 0})'),
                      ],
                    ),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        if (realestate.secteur?.name != null)
                          Chip(
                            avatar: Icon(Icons.place_outlined,
                                size: 15, color: Colors.orange.shade800),
                            label: Text(realestate.secteur!.name!),
                            backgroundColor: Colors.orange.shade50,
                          ),
                        if (realestate.category?.name != null)
                          Chip(
                            label: Text(realestate.category!.name!),
                            backgroundColor: Colors.blue.shade50,
                          ),
                        if (realestate.typeTransaction?.name != null)
                          Chip(
                            label: Text(realestate.typeTransaction!.name!),
                            backgroundColor: Colors.green.shade50,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
