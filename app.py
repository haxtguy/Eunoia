import spacy
from flask import Flask, request, jsonify
from spacytextblob.spacytextblob import SpacyTextBlob


app = Flask(__name__)

nlp = spacy.load('en_core_web_sm')
nlp.add_pipe('spacytextblob')

def add_and(phrases, pos):
    if len(phrases) == 0:
        return ""

    phrases = list(set(phrases))
    youre = "you're"
    if len(phrases) == 1:
        return f"{'you' if pos == 'VERB' else youre} {phrases[0]}"

    return f"{'you' if pos == 'VERB' else youre} " + ",".join(phrases[:-1]) + f" and {phrases[-1]}" # yes i combined concatenation and f-string kys rahukl

def phrase_builder(verb, adv):
    return f'{verb}{", and that " if verb and adv else ""}{adv}'

@app.route('/mood', methods=['POST'])
def mood():
    data = request.get_json()
    doc = nlp(data["text"])

    custom = {"positive": {"VERB": [], "ADV": []}, "negative": {"VERB": [], "ADV": []}}

    for assessment in doc._.blob.sentiment_assessments.assessments:
        phrase, polarity, subjectivity, _ = assessment
        token = [token for token in doc if token.text.lower() in phrase][0]
        phrase = " ".join(phrase)
        pos = "ADV" if token.pos_ == "ADJ" else token.pos_
        if pos not in ["ADV", "VERB"]:
            continue

        custom["positive" if polarity > 0 else "negative"][pos].append(phrase)

    neg_verb, neg_adv, pos_verb, pos_adv = (
        add_and(custom["negative"]["VERB"], "VERB"),
        add_and(custom["negative"]["ADV"], "ADV"),
        add_and(custom["positive"]["VERB"], "VERB"),
        add_and(custom["positive"]["ADV"], "ADV")
    )

    neg, pos, = phrase_builder(neg_verb, neg_adv), phrase_builder(pos_verb, pos_adv)

    if doc._.blob.polarity < 0:
        response = f"I'm sorry to hear that {neg}. "
        if pos:
            response += f"But, I'm glad to hear that {pos}! "

        response += "Try to latch on to the positive aspects of your day so far."

    else:
        response = f"I'm glad to hear that {pos}"
        if neg:
            response += f", even though {neg}"

        response += ". Keep pushing through the day and keep up the positivity."

    response += " You can do this! And remember, if you ever need motivation, just make another log and I'll be sure to listen to the best of my ability."
    return jsonify({"response": response, "polarity": doc._.blob.polarity})

app.run(host="0.0.0.0", debug=True)
