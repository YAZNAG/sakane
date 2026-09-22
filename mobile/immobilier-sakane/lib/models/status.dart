

class Status{
  String? name;
  String? value;
  String? color;

  Status({
    this.name,
    this.value,
    this.color
  });

  Map<String, dynamic> toJson() {
    return {
      'name': this.name,
      'value': this.value,

    };
  }

  factory Status.fromJson(Map<String, dynamic> json) {
    return Status(
      name: json['name'] ?? json["status"],
      value: json['value']??json["code"] ,
      color: json["color"]
    );
  }

}