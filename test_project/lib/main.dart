String reverse(String s) => s.split('').reversed.join('');
void main() {
  var result = reverse("hello");
  print(result);
}