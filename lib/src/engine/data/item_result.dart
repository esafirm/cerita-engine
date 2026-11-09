class ItemResult {
  final String? variable;
  final String? value;
  final String? target;

  const ItemResult.input(this.variable, this.value) : target = null;

  const ItemResult.choice(this.variable, this.value, this.target);
}

