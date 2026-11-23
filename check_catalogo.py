import json
with open('datos/catalogo.json', encoding='utf-8') as f:
    data = json.load(f)
probs = data['result']['problems']
print('total:', len(probs))
with_rating = sum(1 for p in probs if 'rating' in p)
with_points = sum(1 for p in probs if 'points' in p and 'rating' not in p)
print('con rating:', with_rating)
print('con points sin rating:', with_points)
print('sin rating ni points:', len(probs) - with_rating - with_points)
